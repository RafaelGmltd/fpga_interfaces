`default_nettype none
module uart_rx
#(

  parameter OVERSAMPLE_RATE =          16,                              // Common choices: 8 or 16
  parameter NUM_BITS        =          11,                              // 1 start bit, 8 databit, 1 parity bit, 1 stop bit
  parameter PARITY_ON       =           1,                              // 0: Parity disabled. 1: Parity enabled.
  parameter PARITY_EO       =           1                               // 0: Even parity. 1: Odd parity.
)
(
  input wire                     clk_i,
  input wire                     rst_i,
  input wire                     tick_i,
  input wire                     rxd_i,                                 // receiving one bit at a time
  output logic  [NUM_BITS -4 :0] rxd_byte_o,                            // output is a vector of data bits
  output logic                   rxd_vld_o,                             // when all bits are received, data is ready
  output logic                   rxd_err_o                              // parity check (even/odd) is performed; if an error is detected — handle accordingly
   
);

//-------------------------------------------------------------------------------------------------
// temporary register holds values 
logic [NUM_BITS -1       :0]      rxd_buf;                              // input byte
logic [$clog2(NUM_BITS)-1:0]      rxd_buf_cnt;                          // packet of bytes (start data parity stop) 

//-------------------------------------------------------------------------------------------------
// Parity even/odd encoding
localparam EVEN_PAR = 0; 
localparam ODD_PAR  = 1;  

//-------------------------------------------------------------------------------------------------
// It's a majority filter that outputs the value occurring at least twice among the last three input bits 
logic [2:0] rxd;
logic       rxd_sync;    
always_ff @(posedge clk_i) 
begin
  if (rst_i)
    begin 
      rxd      <= 3'b111;
      rxd_sync <= 1'b1;
    end
  else  
    begin        
      rxd      <= {rxd[1:0], rxd_i};
      rxd_sync <= (rxd[2])? (rxd[1] | rxd[0]) : (rxd[1] & rxd[0]);
    end
end
//------------------------------------------------------------------------------------------------- 
// Ticks counter 
logic [$clog2(OVERSAMPLE_RATE)-1:0] ticks_cnt; 

//-------------------------------------------------------------------------------------------------
// This is a counter of ones over 16 ticks, based on which the final output bit (1 or 0) is decided
// If you have 16 ticks, then 8 is exactly half of 16. So, if the count of ones during these 16 ticks is 8 or more, 
// the final bit will be 1; otherwise, it will be 0
localparam [4:0] LEVEL    = 5'd8; 
logic[$clog2(OVERSAMPLE_RATE) :0] rxd_ones_cnt;                         // this is a counter that increments on every tick whenever the input bit is 1 
wire   rxd_bit;                                                         // this is the final processed bit that will be stored in the buffer and then sent to the data output
assign rxd_bit = (rxd_ones_cnt < LEVEL)? 1'b0 : 1'b1;                   // here we compare: if the counter is greater than 8, then output 1; if less than 8, output 0

//-------------------------------------------------------------------------------------------------


// this is an FSM: initial state → processing data bits → parity check → stop bit.
//-------------------------------------------------------------------------------------------------

// Control FSM
typedef enum logic[2 :0] {
  RX_IDLE, 
  RX_DATA,
  RX_NEXT, 
  RX_STOP_BIT,
  RX_STOP
  }state_t;
  state_t state;
  
always_ff @(posedge clk_i)
begin
  if (rst_i) 
  begin
    state       <= RX_IDLE;
    ticks_cnt   <= '0;
    rxd_buf_cnt <= '0;
    rxd_err_o   <= 1'b0;
    rxd_vld_o     <= 1'b0;
  end 
  else 
  begin
    case (state)
//-------------------------------------------------------------------------------------------------
    RX_IDLE: 
      begin
        rxd_err_o <= 1'b0;
        rxd_vld_o   <= 1'b0;
        if (tick_i & !rxd_sync) 
        begin                                                           // the first input bit is 0, which means the start bit 
          state        <= RX_DATA;                                             
          ticks_cnt    <= 4'd1;                                         // the tick counter counts up to 16 ticks because one bit lasts for 16 ticks
          rxd_buf_cnt  <= '0;
          rxd_ones_cnt <= '0;
        end
        else
          state        <= RX_IDLE;
      end
//-------------------------------------------------------------------------------------------------
    RX_DATA:                                                            // data bytes processing (angle)
      begin                                                             
      rxd_err_o   <= 1'b0;                            
      rxd_vld_o   <= 1'b0; 
        if (tick_i)                                                    
        begin
          if (ticks_cnt == OVERSAMPLE_RATE - 1 )                         
          begin
            state <= RX_NEXT;
          end
          ticks_cnt      <= ticks_cnt + 1;                              
          rxd_ones_cnt   <= rxd_ones_cnt + {4'd0,rxd_sync};             // a counter that increments on every tick whenever the input bit is 1             
        end
        
      end
//-------------------------------------------------------------------------------------------------
    RX_NEXT:                                                            // data bytes processing (angle)
      begin
      rxd_err_o  <= 1'b0;
      rxd_vld_o  <= 1'b0;
      rxd_buf    <= { rxd_bit,rxd_buf[NUM_BITS -1: 1] };                // bits are sequentially shifted into an array
      rxd_byte_o <= rxd_buf[NUM_BITS -1 :3];                            // this is a slice of bytes that represent the angle value
      if(rxd_buf_cnt < (NUM_BITS -2))                                   // < 9: continue collecting data bytes sequentially 
      begin
        state        <= RX_DATA;
        rxd_buf_cnt  <= rxd_buf_cnt + 4'd1;
        rxd_ones_cnt <= 5'd0;
      end
      else                                                              // after collecting 8 bytes, on the next tick we perform the parity check
      begin
        state        <= RX_STOP_BIT;
        rxd_err_o    <= ( (PARITY_EO==EVEN_PAR &&  ((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) || (PARITY_EO==ODD_PAR  && ~((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) );
        rxd_vld_o    <= ( (PARITY_EO==EVEN_PAR && ~((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) || (PARITY_EO==ODD_PAR  &&  ((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) );
        rxd_ones_cnt <= 5'd0;
      end
      end
//-------------------------------------------------------------------------------------------------
    RX_STOP_BIT: 
      begin
      rxd_err_o <= '0;
      rxd_vld_o <= '0;
      if (tick_i)                                             
      begin
      ticks_cnt    <= ticks_cnt   + 1;                        
      rxd_ones_cnt <= rxd_ones_cnt + {4'd0,rxd_sync};
        if (ticks_cnt  == OVERSAMPLE_RATE - 1 )                         // 16 ticks have passed and the input bit is 1, this is the stop bit, which must be 1 
        begin
          rxd_buf <= { rxd_bit,rxd_buf[NUM_BITS -1: 1] };
          state   <= RX_STOP;                                
        end
        else
        state     <= RX_STOP_BIT;
      end
      end
//-------------------------------------------------------------------------------------------------
    RX_STOP:
      begin
      state      <= RX_IDLE;
      end
//-------------------------------------------------------------------------------------------------
    default: 
    begin
    ticks_cnt   <= '0;
    rxd_buf_cnt <= '0;
    rxd_byte_o  <= '0;
    rxd_err_o   <= 1'b0;
    rxd_vld_o   <= 1'b0;
    state       <= RX_IDLE;
    end 
      endcase
    end
end
//-------------------------------------------------------------------------------------------------
endmodule
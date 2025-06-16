`default_nettype none
module uart_tx 
#(
  parameter OVERSAMPLE_RATE =          16,
  parameter NUM_BITS        =           8, // Within 5-9
  parameter PARITY_ON       =           1, // 0: Parity disabled. 1: Parity enabled.
  parameter PARITY_EO       =           1  // 0: Even parity. 1: Odd parity.
)
  (
  input wire                 clk_i,
  input wire                 rst_i,
  input wire                 tick_i,
  input wire                 fifo_empty_i,
  input wire  [NUM_BITS-1:0] fifo_rd_data_i,
  output wire                fifo_rd_en_o,
  output logic               txd_o

  );

// Parity even/odd encoding
localparam EVEN_PAR = 0;
localparam ODD_PAR  = 1;

// TX byte register
logic [NUM_BITS +2:0] tx_byte;

// Byte index register
logic [3:0] idx;
//Parity bit
logic parity_bit;

// Ticks counter
logic [$clog2(OVERSAMPLE_RATE)-1:0] ticks_cnt;  

// Control FSM
typedef enum logic [1 :0] 
{
    TX_IDLE, 
    TX_GET_DATA, 
    TX_DATA 
}
state_t;
state_t state;

assign txd_o = tx_byte[0];  
assign fifo_rd_en_o = (!fifo_empty_i) && state==TX_IDLE;  
assign parity_bit = (PARITY_EO == EVEN_PAR) ? ^fifo_rd_data_i : ~^fifo_rd_data_i;

always_ff @(posedge clk_i)
if (rst_i) 
begin
  tx_byte           <= 11'b111_1111_1111;
  idx               <= '0;
  state             <= TX_IDLE;
  ticks_cnt         <= '0;
end 
else 
begin  
  case (state)
//-------------------------------------------------------------------------------------------------
    TX_IDLE: 
    begin      
      if (!fifo_empty_i) 
      begin
        state           <= TX_GET_DATA;
      end 
    end 
//-------------------------------------------------------------------------------------------------   
    TX_GET_DATA: 
    begin 
      tx_byte      <= {1'b1, parity_bit, fifo_rd_data_i, 1'b0};
      state        <= TX_DATA;  
    end
//-------------------------------------------------------------------------------------------------    
    TX_DATA: 
    begin 
      if (tick_i) 
      begin
        ticks_cnt <= ticks_cnt + 1;
        if (ticks_cnt == OVERSAMPLE_RATE - 1) 
        begin
          tx_byte   <= {1'b1, tx_byte[NUM_BITS + 2 : 1]};
          ticks_cnt <= '0;
    
          if (idx == 4'd10) 
          begin
            idx   <= '0;
            state <= TX_IDLE;
          end 
          else 
          begin
            idx <= idx + 1;
          end
        end
      end
    end
//-------------------------------------------------------------------------------------------------         
    default: 
    begin      
      tx_byte           <= '0;
      idx               <= '0;
      state             <= TX_IDLE;       
    end      
  endcase
end
endmodule
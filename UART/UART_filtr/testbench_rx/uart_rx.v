module uart_rx
(
input             clk_i,
input             rst_i,
input             tick_i,
input             rxd_i,
output reg        vd_o,
output reg [7 :0] data_o,
output     [3 :0] cnt_of_ticks,
output     [1 :0] fsm_state,
output reg [9 :0] data_buf,
output            bit_i
);
    
localparam [1:0] ST_IDLE        = 2'b00;
localparam [1:0] ST_DATA        = 2'b01;
localparam [1:0] ST_NEXT_STATE  = 2'b10;
localparam [1:0] ST_STOP        = 2'b11;
    
localparam [4:0] LEVEL    = 5'd8; // 1111_1111 half of one tick, majority threshold for noise filtering
    
reg [2:0] rxd;                    // stores the last three samples of rxd_i
reg       rxd_sync;               // filtered RX signal based on the majority of the last 3 samples rxd
reg [9:0] rxd_buf;                // data bits: start bit[9] data[8 :1] stop bit[0]
reg [3:0] rxd_buf_cnt;            // counts number of bits received (up to 10)
reg [4:0] rxd_buf_data;           // counts how many times RX was 1 over 16 ticks, 1 bit more for case overflow 
                                  // used to filter out noise/glitches by checking how many of the 16 samples were high(1) 
                                  // if ≥ LEVEL (8), the bit is considered '1', otherwise '0'
                                  // each tick we sample the filtered RX signal and increment this counter if it's high
reg [3:0] tick_cnt;               // counts ticks from 0 to 15 (16 ticks per bit) 
reg [1:0] state;                  // FSM
wire      rxd_buf_bit;            // final filtered bit after 16 ticks: 1 if ≥ 8 high samples, otherwise 0

// Second-level filter: decides final bit value based on count of '1's    
assign rxd_buf_bit = (rxd_buf_data < LEVEL)? 1'b0 : 1'b1; // как раз проверка больше 8 или меньше 8  едениц за 16 тиков
assign bit_i       =  rxd_buf_bit;  
// First-level metastability filter: 3-sample majority voter to suppress glitches, each system clk
always @ (posedge clk_i)begin
  if (rst_i)
  begin
    rxd      <= 3'b111; // initialize to 1: expecting a start bit (which is 0) 
    rxd_sync <= 1'b1;   // same
    data_buf <= 10'b1111111111;
    rxd_buf  <= 10'b1111111111;
    
  end
  else
  begin
    data_buf     <= rxd_buf;
    rxd      <= {rxd[1 :0], rxd_i};                                   // over three clock cycles, sample and store three values from rxd_i.

    rxd_sync <= (rxd[2])? (rxd[1] | rxd[0]) : (rxd[1] & rxd[0]);      // then apply majority filtering to remove metastability glitches:
                                                                      // if the third value (rxd[2]) is 1, check if either of the previous two (rxd[1] or rxd[0]) is also 1.
                                                                      // if so, treat the signal as 1 - meaning a single 0 is considered a glitch and removed.
                                                                      // if both previous values are 0, then the last 1 is treated as a glitch and filtered out.
                                                                      // conversely, if the third value is 0, check if either of the previous two is 1.
                                                                      // if at least one is 1, treat the 0 as a glitch and output 1.
                                                                      // if both are 1, the 0 is considered a metastability glitch and ignored.
                                                                      // in short, majority wins - this acts as a metastability filter for random bit flips. 
  end
end

//Receive controller
always @ (posedge clk_i)begin
  if (rst_i)
  begin
    state       <= ST_IDLE;
    vd_o        <= 1'b0;
    tick_cnt    <= 4'd0;
    rxd_buf_cnt <= 4'd0;
  end
  else
  begin
  case(state)
  ST_IDLE :
  begin
  vd_o <= 1'b0;
    if (tick_i & !rxd_sync) // the current sampling tick is active, and the RX line is at logic low → the start bit has arrived (in UART, the start bit = 0)
    begin
      state        <= ST_DATA;
      tick_cnt     <= 4'd1;
      rxd_buf_cnt  <= 4'd0;
      rxd_buf_data <= 5'd0;
    end
  end
                            
  ST_DATA :
  begin
    if (tick_i)
    begin
      if (tick_cnt == 4'd15)
      begin
        state      <= ST_NEXT_STATE;
      end
      tick_cnt     <= tick_cnt + 4'd1;
      rxd_buf_data <= rxd_buf_data + {4'd0, rxd_sync}; // this is just a counter that increments by 1 on each tick if rxd_sync == 1, 1 bit more for case of overflow 
                                                       // otherwise it stays the same.
                                                       // it can be written simpler like this for clarity, meaning is the same:
                                                       // rxd_buf_data <= (rxd_sync) ? (rxd_buf_data + 1) : rxd_buf_data; 
    end
  end
                           
  ST_NEXT_STATE :
  begin
    state        <= ( rxd_buf_cnt < 4'd9 )? ST_DATA : ST_STOP; // here we check how many bits out of 10 have been collected. 
                                                               // if less than 10, we go back a step to process the next bit.
                                                               // if more than 9 (i.e. 10 bits received), the reception is complete.
    rxd_buf_cnt  <=   rxd_buf_cnt + 4'd1;                      // we increment the counter that tracks how many bits out of 10 have been processed.
                                                               // at this point, 16 ticks have passed, which means one full bit duration has been sampled and processed. 
    rxd_buf_data <= 5'd0;                                      // update the count of received '1' bits since one full bit period has been processed.
    rxd_buf      <= { rxd_buf_bit, rxd_buf[9:1] };             // shift register used to save each received bit as it is processed (rxd_buf_bit)
  end
                           
  ST_STOP :
  begin
    state  <= ST_IDLE;
    vd_o   <= rxd_buf[9] & !rxd_buf[0]; // signal indicating a full data byte has been received and processed:
                                        // vd_o is asserted (set to 1) when the first start bit is 0 and the last stop bit is 1 (inverted 0).
    data_o <= rxd_buf[8:1];             // extract the data bits by slicing out the start and stop bits,
                                        // since the first (start bit) and last (stop bit) bits are not data but control bits.
  end
  endcase
  end
end

assign     cnt_of_ticks = tick_cnt;
assign     fsm_state    = state; 

endmodule 

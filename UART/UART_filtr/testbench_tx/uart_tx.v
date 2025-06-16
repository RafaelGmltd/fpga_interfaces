module uart_tx
(
input              rst_i,
input              clk_i,
input              tick_i,
input              data_valid_i, 
input      [7 :0]  data_i,       
output             ready_rcv_o, 
output             txd_o,
output reg [9 :0]  data_buffer,
output reg [3 :0]  ticks_count,
output reg [3 :0]  data_count, 
output             fsm_state        
);
    
localparam [0 :0] ST_IDLE = 1'b0;
localparam [0 :0] ST_TX   = 1'b1;
    
reg [7 :0] tx_data;       // array data bit
reg        transfer_data; // flag that there is data to transmit
reg [9 :0] tx_buf;        // vector with all bits: start, data, and stop
reg [3 :0] tx_buf_cnt;    // counter of transmitted bits (from 0 to 9)
reg [3 :0] tick_cnt;      // tick counter (from 0 to 15)
reg        state; 
  
assign fsm_state   = state;      
assign ready_rcv_o = !(data_valid_i | transfer_data); // the signal is 1 only if there is no data to transmit and valid data is available from the upstream interface
assign txd_o       = tx_buf[0];                       // one bit to the output, right side shift register
    
always@(posedge clk_i)
begin
if (rst_i)
  begin
    transfer_data <= 1'b0;
    state         <= ST_IDLE;
    data_buffer      <= 0;
    ticks_count   <= 0;
    data_count    <= 0;
  end
else
  begin
  case(state)
  ST_IDLE:
    begin
        tick_cnt   <= 4'd0;
        tx_buf_cnt <= 4'd0;
        tx_buf     <= (tick_i & transfer_data) ? {1'b1, tx_data, 1'b0}: {10{1'b1}}; 
        state      <= (tick_i & transfer_data) ? ST_TX : ST_IDLE;                   
        if (data_valid_i)                                                           
            begin
              tx_data       <= data_i;                                              // write 8 data bits into data bit 
              transfer_data <= 1'b1;                                                // flag that data is ready to transmit, go to the next state
            end
    end
  
  ST_TX:
    begin   
        state <= (tx_buf_cnt == 4'd10)? ST_IDLE : ST_TX;                            // when all 10 bits are transmitted, go back to initial state
        if (tick_i)
            begin
              tick_cnt <= tick_cnt + 4'd1;                                      
			  if (tick_cnt == 4'd15)
                begin
                  tx_buf_cnt <= tx_buf_cnt + 4'd1;                                  // after 15 ticks, means first of 10 bits is transmitted
                  tx_buf     <= {1'b1, tx_buf[9 :1]};
                                                                                    // bit [0] goes to output, right side  shift register
                end
            end
        if (tx_buf_cnt == 4'd10)                                                    // bit transmission counter: if equal to 10, all bits are transmitted
            begin 
              transfer_data <= 1'b0;                                                // no data to transmit, all processed
            end
    end    
                            
  endcase
  end
end
always@(posedge clk_i)
begin
  data_buffer <= tx_buf; 
  ticks_count <= tick_cnt;
  data_count  <= tx_buf_cnt;
end 
     
endmodule 
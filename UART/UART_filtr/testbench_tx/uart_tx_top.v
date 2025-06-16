module uart_tx_top
#(
  parameter FREQ = 100000000,
  parameter BAUDRATE = 921600
)
(
input         rst_i,
input         clk_i,
input  [1 :0] rate_i,
input         data_valid_i, 
input  [7 :0] data_i,       
output        ready_rcv_o,  
output        txd_o,
output        tick_gen_o,
output [9 :0] data_buffer,
output [3 :0] ticks_count,
output [3 :0] data_count, 
output        fsm_state
);
    
wire tick;
assign tick_gen_o = tick;
    
tick_gen 
#(
    .FREQ     (FREQ    ),
    .BAUDRATE (BAUDRATE)
) 
i_tick
(
    .rst_i  (rst_i ),
    .clk_i  (clk_i ),
    .rate_i (rate_i),
    .tick_o (tick  ) 
);
    
uart_tx 
i_tx
(
.rst_i        (rst_i       ),
.clk_i        (clk_i       ),
.tick_i       (tick        ),
.data_valid_i (data_valid_i), 
.data_i       (data_i      ),       
.ready_rcv_o  (ready_rcv_o ), 
.txd_o        (txd_o       ),
.data_buffer  (data_buffer ),
.ticks_count  (ticks_count ),
.data_count   (data_count  ),
.fsm_state    (fsm_state   ) 
);
       
endmodule 
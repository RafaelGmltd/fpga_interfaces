module uart_top
#(
  parameter FREQ     = 100000000,
  parameter BAUDRATE = 921600
)
(
input         rst_i,
input         clk_i,
//Tick Gen
input  [1 :0] rate_i,

//TX
input         data_valid_i, 
input  [7 :0] data_i,       
output        ready_rcv_o,  
output        tick_gen_o,
output [9 :0] data_buffer_tx,
output [3 :0] ticks_count_tx,
output [3 :0] data_count_tx, 
output        fsm_state_tx,

//RX
output        vd_o,
output [7 :0] data_o,
output [3 :0] ticks_count_rx,
output [1 :0] fsm_state_rx,
output [9 :0] data_buffer_rx

);
wire txdata;    
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
.rst_i          (rst_i          ),
.clk_i          (clk_i          ),
.tick_i         (tick           ),
.data_valid_i   (data_valid_i   ), 
.data_i         (data_i         ),       
.ready_rcv_o    (ready_rcv_o    ), 
.txd_o          (txdata         ),
.data_buffer_tx (data_buffer_tx ),
.ticks_count_tx (ticks_count_tx ),
.data_count_tx  (data_count_tx  ),
.fsm_state_tx   (fsm_state_tx   ) 
);

uart_rx
i_rx
(
.rst_i          (rst_i          ),
.clk_i          (clk_i          ),
.tick_i         (tick           ),
.rxd_i          (txdata          ),
.vd_o           (vd_o           ),
.data_o         (data_o         ),
.ticks_count_rx (ticks_count_rx ),
.fsm_state_rx   (fsm_state_rx   ),
.data_buffer_rx (data_buffer_rx )

);
       
endmodule 
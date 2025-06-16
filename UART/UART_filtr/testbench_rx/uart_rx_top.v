module uart_rx_top
#(
  parameter FREQ = 100000000,
  parameter BAUDRATE = 921600
)
(
input         clk_i,
input         rst_i,
input [1 :0]  rate_i,
input         rxd_i,
output        vd_o,
output [7 :0] data_o,
output        tick_gen_o,
output [3 :0] cnt_of_ticks,
output [1 :0] fsm_state,
output [9 :0] data_buf,
output        bit_i
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
    
uart_rx 
i_rx
(
    .rst_i        (rst_i ),
    .clk_i        (clk_i ),
    .tick_i       (tick  ),
    .rxd_i        (rxd_i ),
    .vd_o         (vd_o  ),
    .data_o       (data_o),
    .cnt_of_ticks (cnt_of_ticks),
    .fsm_state    (fsm_state),
    .data_buf     (data_buf),
    .bit_i        (bit_i)
    );
       
endmodule 
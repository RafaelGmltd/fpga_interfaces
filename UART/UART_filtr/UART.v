module uart 
#(
  parameter FREQ = 100000000,
  parameter BAUDRATE = 921600
)
(
input         clk_i,
input         rst_i,
input [1 :0]  rate_i,
input         rxd_i,
output        txd_o,
input         data_ready_i,
input [7 :0]  data_i,
output        ready_rcv_o,
output        vd_o,
output [7 :0] data_o
);
    
wire tick;
    
uart_tick 
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
    .rst_i  (rst_i ),
    .clk_i  (clk_i ),
    .tick_i (tick  ),
    .rxd_i  (rxd_i ),
    .vd_o   (vd_o  ),
    .data_o (data_o)
    );
    
uart_tx 
i_tx
(
    .rst_i        (rst_i       ),
    .clk_i        (clk_i       ),
    .tick_i       (tick        ),
    .data_ready_i (data_ready_i),
    .data_i       (data_i      ),
    .ready_rcv_o  (ready_rcv_o ),
    .txd_o        (txd_o       )
    );
       
endmodule 
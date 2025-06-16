`default_nettype none

module fpga_top_module
(
  input  wire         clk_i,
  input  wire         rxd_i,
  input  wire [15: 0] sw,
  output wire         txd_o,
  output wire [3:  0] led
  );

logic pll_clk, pll_locked, rxd_err_o, rxd_msg_err_o;
logic cordic_pipe_en_o;
wire rst_i = sw[15];

// Reset synchronizer for PLL
logic [1: 0] sync_reg;
logic        sync_rst;

always_ff @(posedge clk_i or posedge rst_i)
  if (rst_i) 
    sync_reg <= 2'b00;
  else          
    sync_reg <= {sync_reg[0], 1'b1};

assign sync_rst = sync_reg[1];

// LEDs
assign led = {cordic_pipe_en_o, rxd_msg_err_o, rxd_err_o, sync_rst};

//clk_wiz_0 
//clk_wiz_0_inst 
//(
//  .clk_in1  (clk_i      ),
//  .resetn   (~sync_rst  ),
//  .clk_out1 (pll_clk    ),
//  .locked   (pll_locked )
//);

top_module 
#( 
  .OVERSAMPLE_RATE (16),  
  .FREQ            (100_000_000 ),
  .BAUDRATE        (3000000     ),         
  .PARITY_ON       (1           ),
  .PARITY_EO       (1           )
)
top_module_inst 
(
  .clk_i            (clk_i            ),
  .rst_i            (rst_i            ),
  .rate_i           (2'b00            ),
  .rxd_i            (rxd_i            ),
  .txd_o            (txd_o            ),
  .rxd_err_o        (rxd_err_o        ),
  .rxd_msg_err_o    (rxd_msg_err_o    ),
  .cordic_pipe_en_o (cordic_pipe_en_o )
  );

endmodule

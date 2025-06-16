`default_nettype none

module bram #(
  parameter ADDR_WIDTH    = 8,
  parameter DEPTH         = 256,
  parameter DATA_WIDTH    = 8
)
(
  input wire                     clk_wr_i, 
  input wire                     clk_rd_i, 
  input wire                     rst_i,
  input wire                     wr_en_i,
  input wire                     rd_en_i, 
  input wire   [DATA_WIDTH-1 :0] wr_data_i, 
  input wire   [ADDR_WIDTH-1 :0] wr_addr_i, 
  input wire   [ADDR_WIDTH-1 :0] rd_addr_i, 
  output logic [DATA_WIDTH-1 :0] rd_data_o
);
//-------------------------------------------------------------------------------------------------
logic [DATA_WIDTH-1:0] mem [DEPTH-1:0];
//-------------------------------------------------------------------------------------------------
always_ff @(posedge clk_wr_i)
  if (wr_en_i) 
    mem[wr_addr_i]  <= wr_data_i;
//-------------------------------------------------------------------------------------------------
always_ff @(posedge clk_rd_i)
  if (rst_i) 
    rd_data_o <= '0;
  else if(rd_en_i)          
    rd_data_o <= mem[rd_addr_i];
    
endmodule
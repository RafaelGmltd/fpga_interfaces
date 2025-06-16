`default_nettype none

module sync_fifo 
#(
  parameter WIDTH = 8,
  parameter DEPTH = 64
)
(
  input wire                clk_i,
  input wire                rst_i,
  input wire                wr_en_i,
  input wire                rd_en_i,
  input wire   [WIDTH-1 :0] wr_data_i,
  output logic [WIDTH-1 :0] rd_data_o,
  output wire               full_o,
  output wire               empty_o

);
//-------------------------------------------------------------------------------------------------
localparam  ADDR_WIDTH = $clog2(DEPTH);
localparam [ADDR_WIDTH -1:0] max_ptr  = ADDR_WIDTH'(DEPTH - 1); 
//-------------------------------------------------------------------------------------------------
// pointers
logic [ADDR_WIDTH:0] rd_ptr, wr_ptr;
// ram write/read enable
logic ram_wr_en;
logic ram_rd_en;
// circles
logic wr_odd_circle, rd_odd_circle;
//-------------------------------------------------------------------------------------------------

// block ram instance
bram 
#(
  .ADDR_WIDTH (ADDR_WIDTH),
  .DEPTH      (DEPTH     ),
  .DATA_WIDTH (WIDTH     )
) 
i_bram 
(
  .clk_wr_i  (clk_i                   ),
  .clk_rd_i  (clk_i                   ),
  .rst_i     (rst_i                   ),
  .wr_en_i   (ram_wr_en               ),
  .rd_en_i   (ram_rd_en               ),
  .wr_data_i (wr_data_i               ),
  .wr_addr_i (wr_ptr[ADDR_WIDTH-1 :0] ),
  .rd_addr_i (rd_ptr[ADDR_WIDTH-1 :0] ),
  .rd_data_o (rd_data_o               )
);

//-------------------------------------------------------------------------------------------------
assign ram_wr_en   = ( (wr_en_i) && (!full_o)  );
assign ram_rd_en   = ( (rd_en_i) && (!empty_o) );

wire   same_ptr    = (wr_ptr == rd_ptr);
wire   same_circle = (wr_odd_circle == rd_odd_circle);

assign empty_o     = same_ptr & same_circle;
assign full_o      = same_ptr & ~same_circle;
//-------------------------------------------------------------------------------------------------
always_ff @(posedge clk_i)
  if (rst_i) 
  begin
      rd_ptr        <= '0;
      wr_ptr        <= '0;
      wr_odd_circle <= '0;
      rd_odd_circle <= '0;
  end
  else if(ram_wr_en)
  begin
    if (wr_ptr == max_ptr)
      begin
        wr_ptr        <= '0;
        wr_odd_circle <= ~wr_odd_circle;
      end
    else
      wr_ptr        <= wr_ptr + 1'b1; 
  end
//-------------------------------------------------------------------------------------------------
  else if(ram_rd_en)
  begin
    if(rd_ptr == max_ptr)
      begin
        rd_ptr        <= '0;
        rd_odd_circle <= ~rd_odd_circle;
      end
    else
      rd_ptr          <= rd_ptr + 1'b1;
  end

endmodule
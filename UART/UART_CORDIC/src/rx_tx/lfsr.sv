`default_nettype none
module lfsr
#(
  parameter        N    = 8,
  parameter [7 :0] POLY = 8'h9b  
)
(
  input wire            clk_i,
  input wire            rst_i,
  input wire            cnt_en_i,
  input wire            load_i,
  input wire   [N-1 :0] seed_i,
  output logic [N-1 :0] lfsr_o
);

always_ff @ (posedge clk_i)
 if(rst_i)
   lfsr_o <= '0;
else if (load_i)
  lfsr_o  <= seed_i; 
else if (cnt_en_i)
  lfsr_o  <= {lfsr_o[N-2 :0],1'b0} ^ (POLY & {N{lfsr_o[N-1]}});
    
endmodule
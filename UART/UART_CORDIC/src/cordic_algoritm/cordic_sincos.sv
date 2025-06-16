`default_nettype none
import pkg_cordic_sincos::*;

module cordic_sincos 
#(
  parameter STAGES,                                                     // # of pipeline stages = [1,48]
  parameter BITS                                                        // # datapath bitwidth  = [4,48]
)
(
  input  wire                       clk_i,
  input  wire                       rst_i,
  input  wire                       pipe_en_i,
  input  wire                       start_i,
  input  wire signed    [BITS-1 :0] theta_i,                            // -2pi to 2pi (upper 4b are signed integer)
  output wire                       done_o,
  output wire signed    [BITS-1 :0] sin_theta_o,                        // -1 to 1-(2^BITS) (upper 2b are signed integer)
  output wire signed    [BITS-1 :0] cos_theta_o                         // -1 to 1-(2^BITS) (upper 2b are signed integer)

);

logic signed              valid     [STAGES + 1];
logic signed              sign      [STAGES + 1];
// ARRAYS
// the same logic in the pipeline folder using generate (сheck out this folder)
logic signed [BITS-1 :0]   cos      [STAGES + 1];
logic signed [BITS-1 :0]   sin      [STAGES + 1];
logic signed [BITS-1 :0]   theta    [STAGES + 1];
  
// CORDIC PREPROCESSING STAGE
cordic_sincos_preprocess 
#(
  .STAGES     (STAGES),
  .BITS       (BITS  )
  ) 
cordic_preprocess_inst 
(
  .clk_i      (clk_i     ),
  .rst_i      (rst_i     ),
  .pipe_en_i  (pipe_en_i ),
  .start_i    (start_i   ),
  .theta_i    (theta_i   ),
  .valid_o    ( valid [0]),
  .sign_o     ( sign  [0]),
  .cos_o      ( cos   [0]),
  .sin_o      ( sin   [0]),
  .theta_o    ( theta [0])
);
  
// CORDIC PIPELINE STAGES
genvar i;
generate
  for (i = 0; i < STAGES; i++) 
  begin : CORDIC_STAGES_GEN 
    cordic_sincos_stage 
    #(
      .BITS      (BITS         ),
      .STAGE     (i            )
      )
    cordic_inst_i 
    (
      .clk_i     ( clk_i       ),
      .rst_i     ( rst_i       ),
      .pipe_en_i ( pipe_en_i   ),
      .valid_i   ( valid  [i]  ),
      .sign_i    ( sign   [i]  ),
      .cos_i     ( cos    [i]  ),
      .sin_i     ( sin    [i]  ),
      .theta_i   ( theta  [i]  ),
      .valid_o   ( valid  [i+1]),
      .sign_o    ( sign   [i+1]),
      .cos_o     ( cos    [i+1]),
      .sin_o     ( sin    [i+1]),
      .theta_o   ( theta  [i+1])
        );
  end
endgenerate
    
// OUTPUTS
assign done_o      = valid [STAGES];
assign sin_theta_o = sin   [STAGES];
assign cos_theta_o = cos   [STAGES];

endmodule

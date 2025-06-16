`default_nettype none
import pkg_cordic_sincos::*;

module cordic_sincos_preprocess 
#(
  parameter STAGES,
  parameter BITS
) 
(
  input  wire                    clk_i,
  input  wire                    rst_i,
  input  wire                    pipe_en_i,
  input  wire                    start_i,
  input  wire signed [BITS-1 :0] theta_i,
  output wire                    valid_o,
  output wire                    sign_o,
  output wire signed [BITS-1 :0] cos_o,
  output wire signed [BITS-1 :0] sin_o,
  output wire signed [BITS-1 :0] theta_o
);

  // Full range of input is [-2pi, 2pi]. The max rotation range is +/- pi/2, so the input
  // angle must be corrected should it be beyond this limit.
  
  // If input is in range [-pi/2, pi/2], no angle correction needed.
  // If input is in range (pi/2, 3pi/2], subtract input angle by pi and invert sign of results
  // If input is in range (3pi/2, 2pi], subtract input angle by 2pi
  // If input is in range [-3pi/2, -pi/2), add pi to input angle and invert sign of results
  // If input is in range [-2pi, -3pi/2), add 2pi to input angle
  
  // PRE-PROCESSING PIPELINE STAGE 1
logic                    valid_p1;
logic signed [BITS-1 :0] theta_p1;
  
always_ff @(posedge clk_i)
  if (rst_i) 
  begin
    valid_p1  <= 1'b0;
    theta_p1  <= '0;
  end 
  else if (pipe_en_i) 
  begin           
    valid_p1  <= start_i;
    theta_p1  <= theta_i;
  end

  // PRE-PROCESSING PIPELINE STAGE 2
logic                    valid_p2;
logic signed [BITS-1 :0] theta_p2;
logic                    sign_p2;
// Q4.44
logic signed [BITS-1 :0] PI_DIV_2_n,        // pi/2  (float: 1.5707963267948912 ) (180 )
                         PI_n,              // pi    (float: 3.1415926535897825 ) (90  )
                         PI_MULT_3_DIV_2_n, // 3pi/2 (float: 4.712388980384674  ) (270 )
                         PI_MULT_2_n;       // 2pi   (float: 6.283185307179565  ) (360 )
                         
// rounding PI values if need                         
assign PI_DIV_2_n         = round(PI_DIV_2,        BITS) >>> (MAX_D_WIDTH - BITS);
assign PI_n               = round(PI,              BITS) >>> (MAX_D_WIDTH - BITS);
assign PI_MULT_3_DIV_2_n  = round(PI_MULT_3_DIV_2, BITS) >>> (MAX_D_WIDTH - BITS);
assign PI_MULT_2_n        = round(PI_MULT_2,       BITS) >>> (MAX_D_WIDTH - BITS);
  
logic signed [BITS-1 :0] theta_w2;

assign theta_w2 =   ( theta_p1 > PI_MULT_3_DIV_2_n  )  ?   theta_p1 - PI_MULT_2 : //  270 < theta <  360
                    ( theta_p1 > PI_DIV_2_n         )  ?   theta_p1 - PI :        //  90  < theta <  270
                    ( theta_p1 < -PI_MULT_3_DIV_2_n )  ?   theta_p1 + PI_MULT_2 : // -360 < theta < -270
                    ( theta_p1 < -PI_DIV_2_n        )  ?   theta_p1 + PI :        // -270 < theta < -90
                                                           theta_p1;              // -90  < theta <  90

  logic sign_w2;
  assign sign_w2 =  ( theta_p1 > PI_MULT_3_DIV_2_n )    ?   1'b0 :                // same sign
                    ( theta_p1 > PI_DIV_2_n )           ?   1'b1 :                // invert sign
                    ( theta_p1 < -PI_MULT_3_DIV_2_n )   ?   1'b0 :                // same sign
                    ( theta_p1 < -PI_DIV_2_n )          ?   1'b1 :                // invert sign
                                                            1'b0;                 // same sign
    
always_ff @(posedge clk_i)
  if (rst_i) 
  begin
    valid_p2  <= 1'b0;
    theta_p2  <= '0;
    sign_p2   <= 1'b0;
  end 
  else if (pipe_en_i) 
  begin           
    valid_p2  <= valid_p1;
    theta_p2  <= theta_w2;
    sign_p2   <= sign_w2;
  end
    
// Assign preprocessing outputs (ready for the main CORDIC stages!)
// X(0) = cos = K 
// Y(0) = sin = 0
// Z(0) = angle is scaled in Q2.46 fixed-point format
assign valid_o    = valid_p2;
assign sign_o     = sign_p2;
assign cos_o      = round(K[STAGES-1], BITS) >>> (MAX_D_WIDTH - BITS);
assign sin_o      = '0;
// IMPORTANT: Why do we do this shift? Because the package parameters for angles and K values are in Q2.46 format,
// while the input angle from Python is in Q4.44 format. Therefore, we need to shift left by 2 bits to convert Q4.44 to Q2.46.
// For example, if the input angle is 60 degrees, Python represents it in Q4.44:
// 0001.0000 1100 0001 0101 0010 0011 1000 0010 1101 0111 0011
// which equals approximately 1.0471975511965752 radians (60 degrees).
// In this module, we normalize this input angle with π (which is also in Q4.44).
// The next module expects the angle in Q2.46 format to work correctly with the lookup tables,
// which are in Q2.46. Thus, shifting left by 2 bits aligns the scale.
// After shifting left by 2 bits, the value becomes:
// 01.00 0011 0000 0101 0100 1000 1110 0000 1011 0101 1100 1100
// which is still 1.0471975511965752 radians (60 degrees).
// Essentially, it's the same value, but we added two extra bits for the fractional part
// to match the scale of the lookup tables for K and arctan values.
assign theta_o    = theta_p2 << 2;
  
endmodule
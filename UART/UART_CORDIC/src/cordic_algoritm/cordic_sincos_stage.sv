`default_nettype none
import pkg_cordic_sincos::*;

module cordic_sincos_stage 
#(
  parameter BITS,
  parameter STAGE
) 
(
  input wire                    clk_i,
  input wire                    rst_i,
  input wire                    pipe_en_i,
  input wire                    valid_i,
  input wire                    sign_i,
  input wire signed [BITS-1 :0] cos_i,
  input wire signed [BITS-1 :0] sin_i,
  input wire signed [BITS-1 :0] theta_i,
  output reg                    valid_o,
  output reg                    sign_o,
  output reg signed [BITS-1 :0] cos_o,
  output reg signed [BITS-1 :0] sin_o,
  output reg signed [BITS-1 :0] theta_o
);
  
logic signed [BITS-1:0] delta_cos, 
                        delta_sin, 
                        delta_theta;
                        
assign delta_cos   = ( theta_i[BITS-1] ?  sin_i : -sin_i ) >>> STAGE;
assign delta_sin   = ( theta_i[BITS-1] ? -cos_i :  cos_i ) >>> STAGE;
assign delta_theta = ( theta_i[BITS-1] ? round ( ATAN[STAGE], BITS) >>> (MAX_D_WIDTH - BITS) : 
                                         round (-ATAN[STAGE], BITS) >>> (MAX_D_WIDTH - BITS) );

generate

if ( STAGE == MAX_STAGES-1 ) 
begin
  logic [BITS-1:0] cos_sign_check, sin_sign_check;
  assign cos_sign_check = ( sign_i ? -(cos_i + delta_cos) : (cos_i + delta_cos) );
  assign sin_sign_check = ( sign_i ? -(sin_i + delta_sin) : (sin_i + delta_sin) );
  
  always_ff @(posedge clk_i)
    if (rst_i) 
    begin
      valid_o	<= 1'b0;
      sign_o	<= 1'b0;
      cos_o		<= '0;
      sin_o		<= '0;
      theta_o	<= '0;
    end 
    else if (pipe_en_i) 
    begin 			
      valid_o	<= valid_i;
      sign_o	<= sign_i;
      cos_o		<= cos_sign_check;
      sin_o		<= sin_sign_check;
      theta_o	<= theta_i + delta_theta;
    end
end

else
  always_ff @(posedge clk_i)
    if (rst_i) 
    begin
      valid_o	<= 1'b0;
      sign_o	<= 1'b0;
      cos_o		<= '0;
      sin_o		<= '0;
      theta_o	<= '0;
    end 
    else if (pipe_en_i) 
    begin 			
      valid_o	<= valid_i;
      sign_o	<= sign_i;
      cos_o		<= cos_i   + delta_cos;
      sin_o		<= sin_i   + delta_sin;
      theta_o	<= theta_i + delta_theta;
    end

endgenerate

endmodule
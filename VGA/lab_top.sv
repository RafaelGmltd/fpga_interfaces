module lab_top
#(
    parameter CLK         = 100,
              PIXEL_CLK   = 25,
              KEY         = 2,
              SW          = 16,
              LED         = 16,
              DIGIT       = 4,
              
              WIDTH       = 640,
              HEIGHT      = 480,

              RED         = 4,
              GREEN       = 4,
              BLUE        = 4,

              ORDINATE    = $clog2 ( WIDTH   ),
              ABSCISSA    = $clog2 ( HEIGHT  )
)
(

input                   clk,                       
input                   rst,

//- - - - - Keys,Switches,LEDs - - - - - - - 

input        [KEY-1:0]   key,
input        [SW- 1:0]   sw,
output logic [LED-1:0]   led,

//- - - - - Seven Seg Display - - - - - - - 

output logic [      7:0] abcdefgh,
output logic [DIGIT-1:0] digit,

 //- - - - - Graphics - - - - - - -  // 

input        [ORDINATE      - 1:0] x,
input        [ABSCISSA      - 1:0] y,

output logic [RED   - 1:0        ] red,
output logic [GREEN - 1:0        ] green,
output logic [BLUE  - 1:0        ] blue
);

strobe_gen
#(.CLK_MHZ(CLK), .STRB_HZ(10))
sub_strobe_gen
( .strobe(enable), .*);

wire inv_key_0 = ~ key [0];
wire inv_key_1 = ~ key [1];

logic [7:0] dx, dy;

always_ff @ (posedge clk)
begin
if (rst)
begin
  dx <= 4'b0;
  dy <= 4'b0;
end
else if (enable)
begin
  dx <= dx + inv_key_0;
  dy <= dy + inv_key_1;
end
end
              
always_comb
begin
  red   = 0;
  green = 0;
  blue  = 0;
//Land
if (y > HEIGHT * 4 / 5) 
begin
  red   = 4'h2;
  green = 4'h5;
   blue  = 4'h1;
end
//Sun dynamic 
else if ((x - (WIDTH  >> 1)) * (x - (WIDTH  >> 1)) + ((y-dy) - ((HEIGHT >> 1)-100)) * ((y-dy) - ((HEIGHT >> 1)-100)) < ((HEIGHT >> 2) *(HEIGHT >> 2)))
begin
  red   = 4'd15;
  green = 4'd15;
  blue  = 4'd0 ;
end
//Sky gradient   
else
begin
  red   = y[8:5];
  green = y[8:6];
  blue  = 4'hF;   
end   
end

endmodule
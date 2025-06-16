module strobe_gen
#(
  parameter CLK_MHZ     = 100,
            STRB_HZ     = 3
)           
(
input                   clk,                       
input                   rst,
output logic            strobe
);

generate

if (CLK_MHZ == 1)
begin: if_1
  assign strobe       = 1'b1;
end  
else
begin: if_0
  localparam PERIOD   = CLK_MHZ*1000*1000/STRB_HZ, // one period == 33_333_333.33 of CLK_HMZ
             W_CNT    = $clog2(PERIOD);            // width of counter 25                    
  logic     [W_CNT-1 :0]cnt;                       // 25 bit counter
  always_ff@(posedge clk or posedge rst)
  if(rst)
  begin
    cnt    <= '0;
    strobe <= '0;
  end
  // next posedge clk 
  else if (cnt == '0)
  begin
    cnt    <= W_CNT'(PERIOD -1);                 // 33_333_332(10) = 1111111111111111111111111100(2)
    strobe <= '1;                                // this signal will be active each 33_333_333.33 of CLK_HMZ 
  end
  // next posedge clk 
  else
  begin
    cnt    <= cnt - 1'd1;                        // each posedge clk 33_333_332 - 1
    strobe <= '0;
  end 
end
endgenerate
  
endmodule
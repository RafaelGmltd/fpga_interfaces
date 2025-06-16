module test_rx;

logic         clk_i;
logic         rst_i;
logic [1 :0]  rate_i;
logic         rxd_vld_o;
logic         rxd_err_o;
logic         rxd_i;
logic [7 :0]  rxd_byte_o;
logic [2 :0]  fsm_state_rx;



top_module
#(
  .FREQ     (100_000_000),
  .BAUDRATE (921_600)
)
dut
(
.clk_i          (clk_i          ),
.rst_i          (rst_i          ),
.rate_i         (rate_i         ),
.rxd_i          (rxd_i          ),
.rxd_byte_o     (rxd_byte_o     ),
.rxd_vld_o      (rxd_vld_o      ),
.rxd_err_o      (rxd_err_o      ),
.fsm_state_rx   (fsm_state_rx   )

);

parameter CLK_PERIOD = 10;

task data_in(input logic bit_val);
wait( fsm_state_rx == 2 );
begin
rxd_i <= bit_val;
wait( fsm_state_rx == 1 );
end
endtask

initial begin
clk_i <= 0;
forever 
  begin
    #(CLK_PERIOD/2) clk_i <= ~clk_i;
  end
end

initial begin
rst_i  <= 1'b1;
#(CLK_PERIOD);
rst_i <= '0;
end
  
//start bit = 0
initial begin
wait(!rst_i);
begin
rxd_i <= 0;
wait( fsm_state_rx == 1 );
end

//data bits 
//repeat(8)
//begin
//data_in();
//end
data_in(1);
data_in(0);
data_in(1);
data_in(0);
data_in(1);
data_in(0);
data_in(1);
data_in(0);

wait( fsm_state_rx == 2 );
begin
rxd_i <= 1;
end

//stop bit = 1
wait( fsm_state_rx == 3 );
begin
rxd_i <= 1;
wait( fsm_state_rx == 0 );

end


#(50);
$finish();
end

endmodule

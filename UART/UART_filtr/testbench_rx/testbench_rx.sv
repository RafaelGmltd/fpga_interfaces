module testbench_rx;

logic         clk_i;
logic         rst_i;
logic [1 :0]  rate_i;
logic         vd_o;
logic         rxd_i;
logic [7 :0]  data_o;
logic         tick_gen_o;
logic [3 :0]  cnt_of_ticks;
logic [1 :0]  fsm_state;
logic [9 :0]  data_buf;
logic         bit_i;

uart_rx_top
#(
  .FREQ     (100_000_000),
  .BAUDRATE (921_600)
)
dut
(
.clk_i        (clk_i),
.rst_i        (rst_i),
.rate_i       (rate_i),
.vd_o         (vd_o),
.rxd_i        (rxd_i),
.data_o       (data_o),
.tick_gen_o   (tick_gen_o),
.cnt_of_ticks (cnt_of_ticks),
.fsm_state    (fsm_state),
.data_buf     (data_buf),
.bit_i        (bit_i)
);

parameter CLK_PERIOD = 10;

task data_in();
wait( fsm_state == 2 );
begin
rxd_i <= $random & 1;
wait( fsm_state == 1 );
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
rate_i <= 2'd0;
#(CLK_PERIOD);
rst_i <= '0;
end
  
//start bit = 0
initial begin
wait(!rst_i);
begin
rxd_i <= 0;
wait( fsm_state == 1 );
end

//data bits 
repeat(8)
begin
data_in();
end

//stop bit = 1
wait( fsm_state == 2 );
begin
rxd_i <= 1;
wait( fsm_state == 1 );
wait( fsm_state == 2 );
end


#(50);
$finish();
end

endmodule
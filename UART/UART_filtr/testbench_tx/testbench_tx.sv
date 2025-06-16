module testbench_tx;

logic        rst_i;
logic        clk_i;
logic [1 :0] rate_i;
logic        data_valid_i; 
logic [7 :0] data_i;       
logic        ready_rcv_o;  
logic        txd_o;
logic        tick_gen_o;
logic [9 :0] data_buffer;
logic [3 :0] ticks_count;
logic [3 :0] data_count;
logic        fsm_state;

uart_tx_top
#(
  .FREQ     (100_000_000),
  .BAUDRATE (921_600) 
)
dut
(
.rst_i        (rst_i       ),
.clk_i        (clk_i       ),
.tick_gen_o   (tick_gen_o  ),
.rate_i       (rate_i      ),
.data_valid_i (data_valid_i), 
.data_i       (data_i      ),       
.ready_rcv_o  (ready_rcv_o ), 
.txd_o        (txd_o       ),
.data_buffer  (data_buffer ),
.ticks_count  (ticks_count ),
.data_count   (data_count  ),
.fsm_state    (fsm_state    )
);
parameter CLK_PERIOD = 10;

//task data_in();
//begin
//end
//endtask

initial
begin
  clk_i <= 0;
forever
  begin
  #(CLK_PERIOD/2)
  clk_i <= ~clk_i;
  end
end

initial
begin
  rst_i  <= 1'b1;
  rate_i <= 2'd0; 
  @(posedge clk_i);
  rst_i  <= 1'b0;
end

initial
begin
  wait(ready_rcv_o)
    begin
      data_i <= 8'b0000_1111;
    end
end

initial
begin
wait(~rst_i)
  begin
  data_valid_i <= 0;
  @(posedge clk_i)
  data_valid_i <= 1;
  wait(fsm_state == 1);
    begin
      wait(fsm_state == 0);
      begin
      data_valid_i <= 0;
      end
    end
  #(20); 
  end 
$finish();
end

endmodule
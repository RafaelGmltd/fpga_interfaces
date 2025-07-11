module testbench_RX_TX;

logic        rst_i;
logic        clk_i;
logic [1 :0] rate_i;

//TX
logic        data_valid_i; 
logic [7 :0] data_i;       
logic        ready_rcv_o;  
logic        tick_gen_o;
logic [9 :0] data_buffer_tx;
logic [3 :0] ticks_count_tx;
logic [3 :0] data_count_tx;
logic        fsm_state_tx;

//RX
logic        vd_o;
logic [7 :0] data_o;
logic [3 :0] ticks_count_rx;
logic [1 :0] fsm_state_rx;
logic [9 :0] data_buffer_rx;

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

//TX
.data_valid_i   (data_valid_i   ), 
.data_i         (data_i         ),       
.ready_rcv_o    (ready_rcv_o    ), 
.data_buffer_tx (data_buffer_tx ),
.ticks_count_tx (ticks_count_tx ),
.data_count_tx  (data_count_tx  ),
.fsm_state_tx   (fsm_state_tx   ),

//RX
.vd_o           (vd_o           ),
.data_o         (data_o         ),
.ticks_count_rx (ticks_count_rx ),
.fsm_state_rx   (fsm_state_rx   ),
.data_buffer_rx (data_buffer_rx )
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
  wait(fsm_state_tx == 1);
    begin
      wait(fsm_state_tx == 0);
      begin
      data_valid_i <= 0;
      end
    end
  wait(fsm_state_rx == 3)
  @(posedge clk_i)
  wait(data_count_tx == 1)
  #(100); 
  end 
$finish();
end

endmodule
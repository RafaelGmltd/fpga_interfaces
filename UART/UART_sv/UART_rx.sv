module uart_rx
# (
parameter DBIT    = 8, // # data bits
          SB_TICK = 16 // # ticks for stop bits
)
(
input               clk, 
                    reset,
input               rx, 
                    s_tick,

output logic        rx_done_tick,
output logic [7 :0] dout
);

typedef enum bit [1 :0]
{
  idle  = 2'd 0,
  start = 2'd 1,
  data  = 2'd 2,
  stop  = 2'd 3

}
state_e;

state_e state_reg, state_next;

// signal declaration
logic [3 :0] s_reg,
             s_next;

logic [2 :0] n_reg, 
             n_next;

logic [7 :0] b_reg, 
             b_next;

// body
// FSMD state & data registers
always_ff @( posedge clk or posedge reset) begin
if (reset)
begin
  state_reg <= idle;
  s_reg     <= 0;
  n_reg     <= 0;
  b_reg     <= 0;
end
else
begin
  state_reg <= state_next;
  s_reg     <= s_next;
  n_reg     <= n_next;
  b_reg     <= b_next;
end
end

// FSMD next-state logic
always_comb
begin
state_next   = state_reg;
rx_done_tick = 1'b 0;
s_next       = s_reg;
n_next       = n_reg;
b_next       = b_reg;

case (state_reg)
idle :
  if (~rx)
  begin
    state_next = start;
    s_next     = 0;
  end

start :
  if (s_tick)
    if (s_reg == 7)
    begin
      state_next = data;
      s_next     = 0;
      n_next     = 0;
    end
  else
    s_next = s_reg + 1; 

data :
  if (s_tick)
    if (s_reg == 15)
    begin
      s_next = 0;
      b_next = {rx, b_reg [7 :1]};
      if (n_reg == (DBIT -1))
        state_next = stop ;
      else
        n_next = n_reg + 1;
    end
  else
    s_next = s_reg + 1;

stop:
  if (s_tick)
    if (s_reg == (SB_TICK -1))
    begin
      state_next   = idle;
      rx_done_tick =1'b 1;
    end
    else
      s_next = s_reg + 1;

endcase
end

assign dout = b_reg;

endmodule
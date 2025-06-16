module uart_rx
#(

  parameter OVERSAMPLE_RATE =          16, // Common choices: 8 or 16
  parameter NUM_BITS        =          11, // 1 start bit, 8 databit, 1 parity bit, 1 stop bit
  parameter PARITY_ON       =           1, // 0: Parity disabled. 1: Parity enabled.
  parameter PARITY_EO       =           1  // 0: Even parity. 1: Odd parity.
)
(
  input wire                     clk_i,
  input wire                     rst_i,
  input wire                     tick_i,
  input wire                     rxd_i,          // принимаем по одному биту
  output logic  [NUM_BITS -4 :0] rxd_byte_o,         // это на выход вектор из дата битов
  output logic                   rxd_vld_o,        // данные готовы все приняли
  output logic                   rxd_err_o,       // проверка четность не четность если ошибка
   
//debuging
  output        [2 :0]           fsm_state_rx
);

//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  
// Тут временный регистр со значениями с TX 
logic [NUM_BITS -1       :0]      rxd_buf;         // временый регистр куда все биты с TX сохранять будем 
logic [$clog2(NUM_BITS)-1:0]      rxd_buf_cnt;     // это счетчик считанных битов сколько битов записали
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  


//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  
// Parity even/odd encoding
localparam EVEN_PAR = 0; // четное
localparam ODD_PAR  = 1; // нечетное 
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  



//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  
// Это выборка из трек последовательных битов по последнему значению пришедшему [2] делаем вывод 0 или 1 
logic [2:0] rxd;
logic       rxd_sync;    
always_ff @(posedge clk_i) 
begin
  if (rst_i)
    begin 
      rxd      <= 3'b111;
      rxd_sync <= 1'b1;
    end
  else  
    begin        
      rxd      <= {rxd[1:0], rxd_i};
      rxd_sync <= (rxd[2])? (rxd[1] | rxd[0]) : (rxd[1] & rxd[0]);
    end
end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  



//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  
// Это счетчик тиков 
logic [$clog2(OVERSAMPLE_RATE)-1:0] ticks_cnt;  // это счетчик тиков
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  



//Это счетчик единиц за 16 тиков на основании его будем делать вывод 1 или 0 итоговый бит
localparam [4:0] LEVEL    = 5'd8;                  // это число 8 
logic[$clog2(OVERSAMPLE_RATE) :0] rxd_ones_cnt;   // это счетчик который кждый тик будет увеличиваться если на входной бит 1 
wire   rxd_bit;                                   // это уже конечный обработанный бит который будет записываться в буффер а потом на дата аут пойдет
assign rxd_bit = (rxd_ones_cnt < LEVEL)? 1'b0 : 1'b1; // тут срвниваем если счетчик больше 8 значит 1 если меньше 8 0

//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  



// Это FSM начальное состояние -> обрабатываем дата биты -> проверка четности не четности -> стоп бит
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  

  // Control FSM
typedef enum logic[2 :0] {
  RX_IDLE, 
  RX_DATA,
  RX_NEXT, 
  RX_STOP_BIT,
  RX_STOP
  }state_t;
  state_t state;
  
always_ff @(posedge clk_i)
begin
  if (rst_i) 
  begin
    state       <= RX_IDLE;
    ticks_cnt   <= '0;
    rxd_buf_cnt <= '0;
    rxd_err_o   <= 1'b0;
    rxd_vld_o     <= 1'b0;
  end 
  else 
  begin
    case (state)
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  -
    RX_IDLE: 
      begin
        rxd_err_o <= 1'b0;
        rxd_vld_o   <= 1'b0;

        if (tick_i & !rxd_sync) 
        begin                                                             // первый бит входной  0 то есть старт бит 
          state        <= RX_DATA;                                             
          ticks_cnt    <= 4'd1;                                            // счетчик тиков помним что один бит занимет 16 тиков
          rxd_buf_cnt  <= '0;
          rxd_ones_cnt <= '0;
        end
        else
          state        <= RX_IDLE;
      end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  -
    RX_DATA: 
      begin                                                            // пошли на обработку битов
      rxd_err_o <= 1'b0;                            
      rxd_vld_o   <= 1'b0; 
        if (tick_i)                                                     // тик
        begin
          if (ticks_cnt == OVERSAMPLE_RATE - 1 )                       // тут уже до 16 считаем это информациионный бит мы счейчас в середине информационного бита это как по книге  
          begin
            state <= RX_NEXT;
          end
          ticks_cnt      <= ticks_cnt + 1;                             // начали считать тики 
          rxd_ones_cnt   <= rxd_ones_cnt + {4'd0,rxd_sync};
        end
        
      end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -   
    RX_NEXT:
      begin
      rxd_err_o <= 1'b0;
      rxd_vld_o   <= 1'b0;
      rxd_buf   <= { rxd_bit,rxd_buf[NUM_BITS -1: 1] };
      if(rxd_buf_cnt < (NUM_BITS -2))
      begin
        state        <= RX_DATA;
        rxd_buf_cnt  <= rxd_buf_cnt + 4'd1;
        rxd_ones_cnt <= 5'd0;
      end
      else
      begin
        state        <= RX_STOP_BIT;
        rxd_err_o    <= ( (PARITY_EO==EVEN_PAR &&  ((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) || (PARITY_EO==ODD_PAR  && ~((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) );
        rxd_vld_o    <= ( (PARITY_EO==EVEN_PAR && ~((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) || (PARITY_EO==ODD_PAR  &&  ((^rxd_buf[NUM_BITS -1 :3]) ^ rxd_bit)) );
        rxd_ones_cnt <= 5'd0;
      end
      end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -       
    RX_STOP_BIT: 
      begin
      if (tick_i)                                               // тик пришел
      begin
      ticks_cnt    <= ticks_cnt   + 1;                      // считаем тики
      rxd_ones_cnt <= rxd_ones_cnt + {4'd0,rxd_sync};
        if (ticks_cnt  == OVERSAMPLE_RATE - 1 )          // тут если 16 тиков прошло и входной бит 1 это стоп бит он 1 должен быть
        begin
          rxd_buf <= { rxd_bit,rxd_buf[NUM_BITS -1: 1] };
          state   <= RX_STOP;                                  // начали все заново
        end
        else
        state     <= RX_STOP_BIT;
      end
      end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -     
    RX_STOP:
      begin
      state      <= RX_IDLE;
      rxd_byte_o <= rxd_buf[8 :1]; 
      end

    default: 
    begin
    ticks_cnt   <= '0;
    rxd_buf_cnt <= '0;
    rxd_byte_o  <= '0;
    rxd_err_o   <= 1'b0;
    rxd_vld_o   <= 1'b0;
    state       <= RX_IDLE;
    end 
      endcase
    end
end
//- - - - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  - - -  - - - -  - - - - - -  - - - - - -  - - - - - - - - - -  - - - - - -  - - - - - -  -
assign fsm_state_rx = state;
endmodule
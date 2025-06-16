// асинхронный ресет писать надо и ресетить все в олвис блоке в топ модуль его вынести
/*
logic [1: 0] sync_reg;
logic        sync_rst;

always_ff @(posedge clk_i or posedge rst_i)
  if (rst_i) 
    sync_reg <= 2'b00;
  else          
    sync_reg <= {sync_reg[0], 1'b1};

assign sync_rst = sync_reg[1];
*/

module i2c_phy
    (
    input        i_clk,
    input        i_rst,
        
    output logic o_i2c_ce,
    inout        io_i2c_data,
    output logic o_i2c_clk,
        
        
    input        i_wr_en,
    input [7: 0] i_wr_addr,
    input [7: 0] i_wr_data,
        
    input               i_rd_en,
    input        [7: 0] i_rd_addr,
    output logic        o_rd_valid,
    output logic [7: 0] o_rd_data = 0

    );
    
    typedef enum logic [1: 0]
    {
    ST_IDLE,
    ST_TX,
    ST_TX_ADDR,
    ST_RX_DATA
    }
    state_e;
    state_e state
    
    localparam IO_WRITE = 0;
    localparam IO_READ  = 1;

    logic        parity;
    logic        dir;
    logic        wr_bit;
    logic [7: 0] data_buf;
    logic [4: 0] cnt;
    logic        rd_bit;
    logic        rd_valid ;
    
//-----------------------------------------------------------------------------------------------------   
    IOBUF m_iobuf
    (
      .O  (rd_bit      ),         // Buffer output
      .IO (i2c_data_io ),         // Buffer inout port (connect directly to top-level port)
      .I  (wr_bit      ),         // Buffer input
      .T  (dir         )          // 3-state enable input, high=input, low=output
    );
//----------------------------------------------------------------------------------------------------- 
    always @ (posedge i_clk)
    begin
      o_rd_valid    <= rd_valid; 
      if (rd_valid)
        o_rd_data_o <= data_buf;
    end
//-----------------------------------------------------------------------------------------------------   
    always @ (posedge i_clk)
    begin
      if (rst_i)
      begin
        parity   <= '0;
        dir      <= '0;
        data_buf <= '0;
        cnt      <= '0;
        rd_valid <= '0;
        state    <= ST_IDLE;
        end
      else
      begin      
      case(state)
//----------------------------------------------------------------------------------------------------- 
        ST_IDLE:
          begin
            o_i2c_ce  <= 0;
            o_i2c_clk <= 0;
            cnt       <= 0;
            parity    <= 0;
            rd_valid  <= 0;
            if (i_wr_en)
            begin
              dir      <= IO_WRITE;
              data_buf <= wr_addr_i;
              state    <= ST_TX;
            end
            else if (i_rd_en)
            begin
              dir      <= IO_WRITE;
              data_buf <= i_rd_addr;
              state    <= ST_TX_ADDR;                   
            end
          end
//----------------------------------------------------------------------------------------------------- 
        ST_TX:
          begin
            o_i2c_ce  <= 1;
            o_i2c_clk <= parity;     
            parity    <= ~parity;

            // wr_bit <= data_buf[7];        
            wr_bit <= data_buf[0];
              if (parity)
              begin
                cnt <= cnt + 1;
                if (cnt == 7)
                  data_buf <= wr_data_i;
                else
//                data_buf <= {data_buf[6:0],1'b0};
                  data_buf <= {1'b0,data_buf[7:1]};                      
              end
              if (cnt == 16)
                state <= ST_IDLE;
          end
//----------------------------------------------------------------------------------------------------- 
        ST_TX_ADDR:
          begin     
            o_i2c_ce  <= 1;
            o_i2c_clk <= parity;
            parity    <= ~parity;        
//          wr_bit    <= data_buf[7];
            wr_bit    <= data_buf[0];
            if (parity)
            begin                    
//            data_buf <= {data_buf[6:0],1'b0};
              data_buf <= {1'b0,data_buf[7:1]};                    
              if (cnt == 7)
                begin
                  cnt <= 0;
                  state <= ST_RX_DATA;
                end
                else
                  cnt <= cnt + 1;
                end
            end
//-----------------------------------------------------------------------------------------------------     
        ST_RX_DATA:
          begin
            dir <= IO_READ;
            o_i2c_ce_o  <= 1;
            o_i2c_clk_o <= parity;        
            parity      <= ~parity;
            if (parity)
            begin
              cnt <= cnt + 1;
              //data_buf <= {data_buf[6:0],rd_bit};       
                data_buf <= {rd_bit,data_buf[7:1]};
            end        
              if (cnt == 8)
              begin    
                state    <= ST_IDLE;
                rd_valid <= 1;
              end  
          end         
      endcase
      end
    end   
endmodule
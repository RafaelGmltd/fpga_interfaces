`default_nettype none

import pkg_msg::*;

module uart_tx_msg (
input wire      clk_i,
input wire      rst_i,
    
// from uart_rx_msg
input wire [7:0]    cmd_reg_i,
input wire          cmd_vld_i,
input wire          rxd_msg_err_i,
input wire [7:0]    burst_cnt_i,
input wire          burst_cnt_vld_i,
    
// from cordic
input wire [47:0]   cordic_sin_theta_i,
input wire [47:0]   cordic_cos_theta_i,
input wire          cordic_done_i,
    
// to fifo
output reg [7:0]    txd_byte_o,
output reg          txd_byte_vld_o

);
  
// LFSR to calculate CRC8
logic        lfsr_cnt_en, 
             lfsr_load;

logic [7 :0] lfsr_seed, 
             lfsr_reg;
 
lfsr
#(
  .N    (8   ),
  .POLY (POLY)
)
i_lfsr
(
  .clk_i    (clk_i       ),
  .rst_i    (rst_i       ),
  .cnt_en_i (lfsr_cnt_en ),
  .load_i   (lfsr_load   ),
  .seed_i   (lfsr_seed   ),
  .lfsr_o   (lfsr_reg    )
);
  
// LFSR control FSM
typedef enum logic [1 :0] 
{
    LFSR_STATE_LOAD, 
    LFSR_STATE_COUNT,
    LFSR_DONE
}
lfsr_state_t;
lfsr_state_t 
lfsr_state;

logic [3 :0] count2eight;
logic        crc_byte_done;
    
always_ff @(posedge clk_i)
  if (rst_i) 
  begin
    count2eight         <= '0;
    crc_byte_done       <= 1'b0;
    lfsr_load           <= 1'b0;
    lfsr_cnt_en         <= 1'b0;
    lfsr_seed           <= '0;
    lfsr_state          <= LFSR_STATE_LOAD;
  end

  else 
  begin    
    crc_byte_done     <= 1'b0;
    lfsr_load         <= 1'b0;
    lfsr_cnt_en       <= 1'b0;
// Here, on the contrary, a new packet is being formed and a new CRC will be calculated based on the sin and cos values from the CORDIC. We wait for txd_byte_vld_o
// Note that this happens only when CORDIC finishes calculations. Then, via the LFSR, we first send the HEADER (tx_byte_o),
// which immediately becomes the direct output to the FIFO. The HEADER goes out first, then CMD, followed by 12 bytes representing sin and cos values,
// and finally the last byte is the lfsr_reg — the CRC computed from all 14 bytes.   
    case (lfsr_state) 
      LFSR_STATE_LOAD: 
      begin
        if (txd_byte_vld_o) 
        begin   
            lfsr_load   <= 1'b1;
            lfsr_seed   <= lfsr_reg ^ txd_byte_o; 
            lfsr_state  <= LFSR_STATE_COUNT;
        end
        end

      LFSR_STATE_COUNT: 
      begin
        lfsr_cnt_en <= 1'b1;
        count2eight   <= count2eight + 1;
        if (count2eight == 7) 
        begin
            count2eight     <= '0;
            lfsr_state      <= LFSR_DONE;
        end
      end

      LFSR_DONE: 
      begin
        crc_byte_done   <= 1'b1;
        lfsr_state      <= LFSR_STATE_LOAD;
      end
        default: begin
          crc_byte_done     <= 1'b0;
          count2eight       <= '0;
          lfsr_load         <= 1'b0;
          lfsr_cnt_en       <= 1'b0;
          lfsr_seed         <= '0;
          lfsr_state        <= LFSR_STATE_LOAD;
        end

    endcase
      
    if (rxd_msg_err_i) 
    begin
        crc_byte_done     <= 1'b0;
        count2eight       <= '0;
        lfsr_load         <= 1'b0;
        lfsr_cnt_en       <= 1'b0;
        lfsr_seed         <= '0;
        lfsr_state        <= LFSR_STATE_LOAD;
    end
  end
  
// FSM to recognize current operating cmd (length of operands needed for range cmd)
// Once cmd is recognized, accept cordic outputs and transmit byte-wise to uart_tx along w/ crc
typedef enum logic [3 :0]
{
    STATE_IDLE,
    STATE_SINGLE_TRANS,
    STATE_SINGLE_TRANS_II,
    STATE_SINGLE_TRANS_III,
    STATE_BURST_TRANS,
    STATE_BURST_TRANS_II,
    STATE_BURST_TRANS_III,
    STATE_BURST_TRANS_IV,
    STATE_BURST_TRANS_V,
    STATE_TX_CRC8
}
tx_msg_state_t;

tx_msg_state_t tx_msg_state;

logic [7 :0] burst_cnt;                                                 
logic [7 :0] bytes2send [12];                                           // array to collect 12 bytes of data from CORDIC: 6 bytes for Cosine and 6 bytes for Sine
logic [3 :0] byte_cnt;

always_ff @(posedge clk_i)
  if (rst_i) 
  begin
    tx_msg_state      <= STATE_IDLE;
    bytes2send        <= '{default:'0};
    byte_cnt          <= '0;
    byte_cnt          <= '0;
    txd_byte_vld_o    <= 1'b0;
    txd_byte_o        <= '0;
  end 
  else 
  begin    
    txd_byte_vld_o   <= 1'b0;

    case (tx_msg_state)
//-------------------------------------------------------------------------------------------------
      STATE_IDLE:
      begin
        if (cmd_vld_i)                                                   
        begin
          case (cmd_reg_i) 
                CMD_SINGLE_TRANS:   tx_msg_state  <= STATE_SINGLE_TRANS;
                CMD_BURST_TRANS:    tx_msg_state  <= STATE_BURST_TRANS;
                default:            tx_msg_state  <= STATE_IDLE;
          endcase
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_SINGLE_TRANS: 
      begin
      byte_cnt            <= 12;                                              // 12 bytes from cordic
        if (cordic_done_i) 
        begin                                                                 // you can use a for loop inside an always block even if there are no module instances
            for (int i = 0; i < 6; i++)                                       // 6 iterations, the CORDIC output cosine values are saved into the first 6 positions of the array, while the sine values are stored in the following 6 positions
            begin
                bytes2send[i]       <= cordic_cos_theta_i[(8*i)+7 -: 8];      // [N -: M]  extract M bits starting from bit N counting down towards the lower (less significant) bits
                bytes2send[i+6]     <= cordic_sin_theta_i[(8*i)+7 -: 8];      // [N : (N - M)+1] -> [15 -: 8] -> [15 :8]
            end
            txd_byte_vld_o       <= 1'b1;                                     // right now, only the first byte (header) is sent to both the output and the FIFO and LFSR
            txd_byte_o           <= BYTE_HEADER;
            tx_msg_state         <= STATE_SINGLE_TRANS_II;
        end

        if (cmd_vld_i) 
        begin
        case (cmd_reg_i) 
          CMD_SINGLE_TRANS:   tx_msg_state  <= STATE_SINGLE_TRANS;
          CMD_BURST_TRANS:    tx_msg_state  <= STATE_BURST_TRANS;
          default:            tx_msg_state  <= STATE_IDLE;
        endcase
        end 
        end     
//-------------------------------------------------------------------------------------------------
      STATE_SINGLE_TRANS_II: 
      
      begin
        if (crc_byte_done)                                                    // the first byte (header) has been processed through the LFSR
        begin
            txd_byte_vld_o         <= 1'b1;                                   // (cmd) is sent to both the output and the FIFO and LFSR
            txd_byte_o             <= CMD_SINGLE_TRANS;
            tx_msg_state           <= STATE_SINGLE_TRANS_III;
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_SINGLE_TRANS_III: 
      begin
        if (crc_byte_done) 
        begin
            txd_byte_vld_o     <= 1'b1;                                        // here we start sequentially feeding the array values (sin and cos calculated by the CORDIC) into both the LFSR and the FIFO
            txd_byte_o         <= bytes2send[12 - byte_cnt];                    
            byte_cnt           <= byte_cnt - 1;                              
                if (byte_cnt == 1)                                             
                begin
                    tx_msg_state    <= STATE_TX_CRC8;
                end
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_BURST_TRANS: 
      begin
        if (burst_cnt_vld_i) 
        begin
          burst_cnt       <= burst_cnt_i;
        end
        byte_cnt          <= 12;
        if (cordic_done_i) 
        begin
          for (int i = 0; i < 6; i++) 
          begin
            bytes2send[i]     <= cordic_cos_theta_i[(8*i)+7 -: 8];
            bytes2send[i+6]   <= cordic_sin_theta_i[(8*i)+7 -: 8];
          end
          txd_byte_vld_o      <= 1'b1;
          txd_byte_o          <= BYTE_HEADER;
          tx_msg_state        <= STATE_BURST_TRANS_II;
        end
        
        if (cmd_vld_i) 
        begin
        case (cmd_reg_i) 
          CMD_SINGLE_TRANS:   tx_msg_state  <= STATE_SINGLE_TRANS;
          CMD_BURST_TRANS:    tx_msg_state  <= STATE_BURST_TRANS;
          default:            tx_msg_state  <= STATE_IDLE;
        endcase
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_BURST_TRANS_II: 
      begin
        if (crc_byte_done) 
        begin
          txd_byte_vld_o      <= 1'b1;
          txd_byte_o          <= CMD_BURST_TRANS;
          tx_msg_state        <= STATE_BURST_TRANS_III;
        end
      end      
//-------------------------------------------------------------------------------------------------
      STATE_BURST_TRANS_III: 
      begin
        if (crc_byte_done) 
        begin
          txd_byte_vld_o        <= 1'b1;
          txd_byte_o            <= burst_cnt;
          tx_msg_state          <= STATE_BURST_TRANS_V;
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_BURST_TRANS_IV: 
      begin
      byte_cnt            <= 11;
        if (cordic_done_i) 
        begin
          for (int i = 0; i < 6; i++) 
          begin
            bytes2send[i]       <= cordic_cos_theta_i[(8*i)+7 -: 8];
            bytes2send[i+6]     <= cordic_sin_theta_i[(8*i)+7 -: 8];
          end
          txd_byte_vld_o     <= 1'b1;
          txd_byte_o         <= cordic_cos_theta_i[7:0];
          tx_msg_state       <= STATE_BURST_TRANS_V;        
        end
      end
//-------------------------------------------------------------------------------------------------
      STATE_BURST_TRANS_V: 
      begin
        if (crc_byte_done) 
        begin
          txd_byte_vld_o     <= 1'b1;
          txd_byte_o           <= bytes2send[12 - byte_cnt];
          byte_cnt            <= byte_cnt - 1;
          if (byte_cnt == 1) 
          begin
            burst_cnt           <= burst_cnt - 1;
            if (burst_cnt == 1)
              tx_msg_state    <= STATE_TX_CRC8;
            else
              tx_msg_state    <= STATE_BURST_TRANS_IV;
          end
        end
      end     
//-------------------------------------------------------------------------------------------------
      STATE_TX_CRC8: 
      begin
        if (crc_byte_done) 
        begin
            txd_byte_vld_o    <= 1'b1;              // we’ve just written the newly computed CRC-8 based on the new sin and cos values — Python client will later calculate its own CRC-8 on the received data and compare it for verification
            txd_byte_o        <= lfsr_reg;
            tx_msg_state      <= STATE_IDLE;
        end
      end
//-------------------------------------------------------------------------------------------------
      default: 
      begin
        tx_msg_state      <= STATE_IDLE;
        txd_byte_vld_o    <= 1'b0;
        txd_byte_o        <= '0;
        bytes2send        <= '{default:'0};
        byte_cnt          <= '0;
        burst_cnt         <= '0;
      end
    endcase
//-------------------------------------------------------------------------------------------------
    if (rxd_msg_err_i) 
    begin
        tx_msg_state      <= STATE_IDLE;
        bytes2send        <= '{default:'0};
        byte_cnt          <= '0;
        txd_byte_vld_o    <= 1'b0;
        txd_byte_o        <= '0;
        burst_cnt         <= '0;
    end    
  end
endmodule
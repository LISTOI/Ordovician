`timescale 1ns / 1ps
module RECEIVE_Matrix(
    input clk,
    input rstn,
    input readstart,
    output logic readdone,
    output logic [31:0] Matrix_A            [0:3][0: 7 ][0:23],
    output logic [31:0] Matrix_B            [0:3][0: 23][0:7 ],
    output logic [31:0] Matrix_C_in         [0:3][0: 7 ][0:7 ],
    input logic [1 :0] Matrix_type, // 0:m8k16n32 1:m16k16n16 2:m32k16n8
    //input logic [5 :0] MUL_valid, // 乘法精度
    //input logic [5 :0] ADD_valid, // 加法精度
    
    // AXI4读通道接口
    output logic [7:0]  axi_arlen,
    output logic [2:0]  axi_arsize,
    output logic [1:0]  axi_arburst,
    output logic        axi_arvalid,
    input  wire         axi_arready,
    input  wire  [31:0] axi_rdata,
    input  wire  [1:0]  axi_rresp,
    input  wire         axi_rlast,
    input  wire         axi_rvalid,
    output logic        axi_rready
);
    typedef enum {
        IDLE,
        CALC_PARAM,
        SEND_ADDR,
        RECEIVE_DATA,
        DONE
    } state_t;

    state_t current_state, next_state;
    // 矩阵参数配置
    logic [7:0] m_dim, k_dim, n_dim;
    logic [2:0] mat_select; // 0:A, 1:B, 2:C
    logic [2:0] max_row,max_col;

    // 地址生成控制
    logic [3:0] blk_cnt;    // 块计数器
    logic [7:0] row_cnt;    // 行计数器
    logic [7:0] col_cnt;    // 列计数器
    logic [7:0] valid_cols; // 有效列数

    // 突发传输参数
    logic [7:0] burst_length;

    always_comb begin
        case(Matrix_type)
            2'b00: begin // m8k16n32
                m_dim = 8;
                max_row = 1;
                k_dim = 16;
                n_dim = 32;
                max_col = 4;
            end
            2'b01: begin // m16k16n16
                m_dim = 16;
                max_row = 2;
                k_dim = 16;
                n_dim = 16;
                max_col = 2;
            end
            2'b10: begin // m32k16n8
                m_dim = 32;
                max_row = 4;
                k_dim = 16;
                n_dim = 8;
                max_col = 1;
            end
            default: begin
                m_dim = 8;
                max_row = 1;
                k_dim = 16;
                n_dim = 32;
                max_col = 4;
            end
        endcase
    end

    // 主状态机
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            current_state <= IDLE;
            {axi_arvalid, axi_rready} <= 2'b0;
            {blk_cnt, row_cnt, col_cnt, valid_cols} <= 0;
            {mat_select, readdone} <= 0;
            Matrix_A <= '{default:'0};
            Matrix_B <= '{default:'0};
            Matrix_C_in <= '{default:'0};
        end else begin
            current_state <= next_state;
            
            case(current_state)
                IDLE: begin
                    readdone <= 0;
                    if(readstart) begin
                        mat_select <= 0;
                        blk_cnt    <= 0;
                        row_cnt    <= 0;
                        col_cnt    <= 0;
                        valid_cols <= 0;
                        Matrix_A <= '{default:'0};
                        Matrix_B <= '{default:'0};
                        Matrix_C_in <= '{default:'0};
                        next_state <= CALC_PARAM;
                    end
                end
                
                CALC_PARAM: begin
                    
                    // 计算突发长度
                    burst_length <= (mat_select == 0) ? k_dim/4 - 1 : n_dim/4 - 1;
                    
                    axi_arlen  <= burst_length;
                    axi_arsize <= 3'b010;   // 32-bit传输
                    axi_arburst <= 2'b01;   // INCR模式
                    next_state <= SEND_ADDR;
                end
                
                SEND_ADDR: begin
                    axi_arvalid <= 1'b1;
                    if(axi_arready) begin
                        axi_arvalid <= 1'b0;
                        axi_rready  <= 1'b1;
                        next_state <= RECEIVE_DATA;
                    end
                end
                
                RECEIVE_DATA: begin
                    if(axi_rvalid && axi_rread) begin
                        // 应用气泡填充
                        case(mat_select)
                            0: begin // Matrix_A
                                if (blk_cnt < max_row) begin
                                    if(col_cnt < k_dim && col_cnt <= valid_cols + 16) begin
                                        Matrix_A[blk_cnt][row_cnt][col_cnt + valid_cols] <= axi_rdata;
                                    end
                                    if (row_cnt < 7) begin
                                        if (col_cnt == valid_cols + 16) begin
                                            col_cnt <= valid_cols;
                                            row_cnt <= row_cnt + 1;
                                            valid_cols <= valid_cols + 1;
                                        end
                                        else col_cnt <= col_cnt + 1;
                                    end
                                    else begin
                                        if (col_cnt == valid_cols + 16) begin
                                            col_cnt <= 0;
                                            row_cnt <= 0;
                                            valid_cols <= 0;
                                            blk_cnt <= blk_cnt + 1;
                                        end
                                        else col_cnt <= col_cnt + 1;
                                    end
                                end
                            end
                            1: begin // Matrix_B
                                if (blk_cnt < max_col) begin
                                    if (col_cnt <= 7 && row_cnt <= valid_cols + 16) begin
                                        Matrix_B[blk_cnt][row_cnt + valid_cols][col_cnt] <= axi_rdata;
                                    end
                                    if (col_cnt < 7) begin
                                        if (row_cnt == valid_cols + 16) begin
                                            row_cnt <= valid_cols;
                                            col_cnt <= col_cnt + 1;
                                            valid_cols <= valid_cols + 1;
                                        end
                                        else row_cnt <= row_cnt + 1;
                                    end
                                    else begin
                                        if (row_cnt == valid_cols + 16) begin
                                            row_cnt <= 0;
                                            col_cnt <= 0;
                                            valid_cols <= 0;
                                            blk_cnt <= blk_cnt + 1;
                                        end
                                        else row_cnt <= row_cnt + 1;
                                    end
                                end
                            end
                            2: begin // Matrix_C_in
                                
                                Matrix_C_in[blk_cnt][row_cnt][col_cnt] <= axi_rdata;
                                
                                if (row_cnt < 7) begin
                                    if (col_cnt == 7) begin
                                        col_cnt <= 0;
                                        row_cnt <= row_cnt + 1;
                                    end
                                    else col_cnt <= col_cnt + 1;
                                end
                                else begin
                                    row_cnt <= 0;
                                    blk_cnt <= blk_cnt + 1;
                                end
                            end
                            
                        endcase

                        if(axi_rlast) begin
                            axi_rready <= 0;
                            next_state <= DONE;
                        end
                        
                    end
                end
                
                DONE: begin
                    readdone <= 1;
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // 下一状态逻辑
    always_comb begin
        case(current_state)
            IDLE:        next_state = readstart ? CALC_PARAM : IDLE;
            CALC_PARAM:  next_state = SEND_ADDR;
            SEND_ADDR:   next_state = axi_arready ? RECEIVE_DATA : SEND_ADDR;
            RECEIVE_DATA:next_state = axi_rlast ? DONE : RECEIVE_DATA;
            DONE:        next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

endmodule
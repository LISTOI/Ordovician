module WRITE_Matrix (
    input clk,
    input rstn,
    input writestart,
    output logic writedone,
    input logic [31:0] Matrix_C         [0:3][0: 7 ][0: 7 ],

    // 写地址通道
    output [31:0] awaddr,
    output        awvalid,
    input         awready,
    // 写数据通道  
    output [31:0] wdata,
    output        wvalid,
    input         wready
);

    typedef enum {IDLE, SEND_ADDR, SEND_DATA, DONE} state_t;
    state_t current_state;

    reg [7:0] blk_cnt,row_cnt,col_cnt;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            writedone <= 0;
        end
        else begin
            case (current_state)
            IDLE: begin
                if (writestart) begin
                    current_state <= SEND_ADDR;
                    writedone <= 0;
                end
            end
            SEND_ADDR: begin
                if (awready) begin
                    awvalid <= 1'b1;
                    current_state <= SEND_DATA;
                end
            end
            SEND_DATA: begin
                if (wready) begin
                    wdata <= Matrix_C[blk_cnt][row_cnt][col_cnt];
                    wvalid <= 1'b1;
                    if (row_cnt < 7) begin
                        if (col_cnt < 7) begin
                            col_cnt <= col_cnt + 1;
                        end
                        else begin
                            col_cnt <= 0;
                            row_cnt <= row_cnt + 1;
                        end
                    end
                    else begin
                        row_cnt <= 0;
                        blk_cnt <= blk_cnt + 1;
                    end
                    if (blk_cnt == 3 && row_cnt == 7 && col_cnt == 7) begin
                        current_state <= DONE;
                    end
                end
            end
            DONE: begin
                writedone <= 1;
            end
            endcase
        end
    end
endmodule
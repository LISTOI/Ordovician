`timescale 1ns / 1ps
module READ_Matrix(
    input clk,
    input rstn,
    input readstart,
    output logic readdone,
    output logic [31:0] Matrix_A            [0:3][0: 7 ][0:23],
    output logic [31:0] Matrix_B            [0:3][0: 23][0:7 ],
    output logic [31:0] Matrix_C_in         [0:3][0: 7 ][0:7 ],
    input logic [1 :0] Matrix_type, // 0:m8k16n32 1:m16k16n16 2:m32k16n8
    output logic [5 :0] MUL_valid, // 乘法精度
    output logic [5 :0] ADD_valid, // 加法精度
    input logic [31:0] data_in,
    input logic [5 :0] 
);
    typedef enum {
        IDLE,
        RECEIVE_TYPE,
        RECEIVE_DATA,
        DONE
    } state_t;

    state_t current_state, next_state;

    logic [31:0] received_data,received_config;
    logic data_valid,config_valid;
    logic [1:0] bresp;
    logic bvalid, bready;
    logic wready, wvalid;

    logic [7:0] blk_cnt, row_cnt, col_cnt;
    logic [1:0] num; // 0:A 1:B 2:C
    logic [7:0] m,n,k;
    logic [7:0] offset;
    
    AXI_slave matrix_read (
        .clk(clk),
        .rstn(rstn),
        .wdata(data_in),
        .wvalid(wvalid),
        .wready(wready),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        .received_data(received_data),
        .data_valid(data_valid)
    );

    AXI_slave config_read (
        .clk(clk),
        .rstn(rstn),
        .wdata(data_in),
        .wvalid(wvalid),
        .wready(wready),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        .received_data(received_config),
        .data_valid(config_valid)
    );

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            readdone <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: if (readstart) next_state = RECEIVE_TYPE;
            RECEIVE_TYPE: if (config_valid) next_state = RECEIVE_DATA;
            RECEIVE_DATA: begin
                if (num <= 2)
                    if (data_valid) next_state = RECEIVE_TYPE;
                else next_state = DONE;
            end
            
            DONE: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            {blk_cnt, row_cnt, col_cnt} <= 0;
            Matrix_A <= '0;
            Matrix_B <= '0;
            Matrix_C_in <= '0;
            {MUL_valid, ADD_valid} <= 0;
            Matrix_type <= 0;
            {data_valid, config_valid} <= 0;
            {received_data, received_config} <= 0;
            readdone <= 0;
            num <= 0;
            {blk_cnt, row_cnt, col_cnt} <= 0;
            {n, m, k, offset} <= 0;
        end
        else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (readstart) begin
                        {blk_cnt, row_cnt, col_cnt} <= 0;
                        Matrix_A <= '0;
                        Matrix_B <= '0;
                        Matrix_C_in <= '0;
                        {MUL_valid, ADD_valid} <= 0;
                        Matrix_type <= 0;
                        {data_valid, config_valid} <= 0;
                        {received_data, received_config} <= 0;
                        readdone <= 0;
                        {blk_cnt, row_cnt, col_cnt} <= 0;
                        {n, m, k, offset} <= 0;
                        num <= 0;
                    end
                end
                RECEIVE_TYPE: begin
                    if (config_valid) begin
                        Matrix_type <= received_data[1:0];
                        if (received_data[1:0] == 2'b00) begin
                            m <= 8;
                            k <= 16;
                            n <= 32;
                        end else if (received_data[1:0] == 2'b01) begin
                            m <= 16;
                            k <= 16;
                            n <= 16;
                        end else if (received_data[1:0] == 2'b10) begin
                            m <= 32;
                            k <= 16;
                            n <= 8;
                        end
                    end
                end
                RECEIVE_DATA: begin
                    if (data_valid) begin
                        if (num == 0) begin // Matrix_A
                            if (blk_cnt < 4) begin
                                if (row_cnt < 8) begin
                                    if (col_cnt < offset + 16) begin
                                        Matrix_A[blk_cnt][row_cnt][col_cnt + offset] <= received_data;
                                        col_cnt <= col_cnt + 1;
                                    end
                                    else begin
                                        col_cnt <= offset;
                                        row_cnt <= row_cnt + 1;
                                        offset <= offset + 1;
                                    end
                                end
                                else begin
                                    row_cnt <= 0;
                                    blk_cnt <= blk_cnt + 1;
                                end
                            end
                        end
                        else if (num == 1) begin // Matrix_B
                            if (blk_cnt < 4) begin
                                if (col_cnt < 8) begin
                                    if (row_cnt < offset + 16) begin
                                        Matrix_B[blk_cnt][row_cnt + offset][col_cnt] <= received_data;
                                        row_cnt <= row_cnt + 1;
                                    end
                                    else begin
                                        row_cnt <= offset;
                                        col_cnt <= col_cnt + 1;
                                        offset <= offset + 1;
                                    end
                                end
                                else begin
                                    col_cnt <= 0;
                                    blk_cnt <= blk_cnt + 1;
                                end
                            end
                        end
                        else if (num == 2) begin // Matrix_C
                            if (blk_cnt < 4) begin
                                if (row_cnt < 8) begin
                                    if (col_cnt < 8) begin
                                        Matrix_C_in[blk_cnt][row_cnt][col_cnt] <= received_data;
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
                            end
                        end
                    end
                end
                DONE: begin
                    readdone <= 1;
                end
            endcase
        end
    end

endmodule
`timescale 1ns / 1ps

module FP32_to_FP16(
    input   wire    [31 : 0]    FP32,
    output  reg     [15 : 0]    FP16
    );

    wire                sign_32 = FP32[31];
    wire     [7 : 0]    exp_32 = FP32[30 : 23];
    wire     [22 : 0]   frac_32 = FP32[22 : 0];

    reg                 sign_16;
    reg     [4 : 0]     exp_16;
    reg     [9 : 0]     frac_16;

    reg     [4 : 0]     exp_rd_16;
    reg     [9 : 0]     frac_rd_16;
    reg                 guard;
    reg                 round;
    reg                 stick;

    always @(*) begin
        sign_16 = sign_32;
        if(exp_32 < 103) begin
            exp_16 = 5'b0;
            frac_16 = 10'b0;
            guard = 0;
            round = 0;
            stick = 0;
        end
        else if(exp_32 < 113) begin
            exp_16 = 5'b0;
            casex(exp_32)
                103: begin
                    frac_16 = {9'b0, 1'b1};
                    guard = 0;
                    round = 0;
                    stick = 0;
                end
                104: begin
                    frac_16 = {8'b0, 1'b1, frac_32[22]};
                    guard = frac_32[21];
                    round = frac_32[20];
                    stick = |frac_32[19 : 0];
                end
                105: begin
                    frac_16 = {7'b0, 1'b1, frac_32[22 : 21]};
                    guard = frac_32[20];
                    round = frac_32[19];
                    stick = |frac_32[18 : 0];
                end
                106: begin
                    frac_16 = {6'b0, 1'b1, frac_32[22 : 20]};
                    guard = frac_32[19];
                    round = frac_32[18];
                    stick = |frac_32[17 : 0];
                end
                107: begin
                    frac_16 = {5'b0, 1'b1, frac_32[22 : 19]};
                    guard = frac_32[18];
                    round = frac_32[17];
                    stick = |frac_32[16 : 0];
                end
                108: begin
                    frac_16 = {4'b0, 1'b1, frac_32[22 : 18]};
                    guard = frac_32[17];
                    round = frac_32[16];
                    stick = |frac_32[15 : 0];
                end
                109: begin
                    frac_16 = {3'b0, 1'b1, frac_32[22: 17]};
                    guard = frac_32[16];
                    round = frac_32[15];
                    stick = |frac_32[14 : 0];
                end
                110: begin
                    frac_16 = {2'b0, 1'b1, frac_32[22 : 16]};
                    guard = frac_32[15];
                    round = frac_32[14];
                    stick = |frac_32[13 : 0];
                end
                111: begin
                    frac_16 = {1'b0, 1'b1, frac_32[22 : 15]};
                    guard = frac_32[14];
                    round = frac_32[13];
                    stick = |frac_32[12 : 0];
                end
                112: begin
                    frac_16 = {1'b1, frac_32[22 : 14]};
                    guard = frac_32[13];
                    round = frac_32[12];
                    stick = |frac_32[11 : 0];
                end
                default: begin
                    frac_16 = 10'b0;
                    guard = 0;
                    round = 0;
                    stick = 0;
                end
            endcase
        end
        else if(exp_32 == {8{1'b1}}) begin
            exp_16 = {5{1'b1}};
            if(|frac_32) begin
                frac_16 = {1'b1, 9'b0};
            end
            else begin
                frac_16 = 10'b0;
            end
            guard = 0;
            round = 0;
            stick = 0;
        end
        else if(exp_32 > 142) begin
            exp_16 = {5{1'b1}};
            frac_16 = 10'b0;
            guard = 0;
            round = 0;
            stick = 0;
        end
        else begin
            exp_16 = (exp_32 - 127) + 15;
            frac_16 = frac_32[22 : 13];
            guard = frac_32[12];
            round = frac_32[11];
            stick = |frac_32[10 : 0];
        end
    end

    always @(*) begin
        if(guard & ((round | stick) | frac_16[13])) begin
            exp_rd_16 = (frac_16 == {10{1'b1}}) ? (exp_16 + 1) : exp_16;
            frac_rd_16 = frac_16 + 1;
        end
        else begin
            exp_rd_16 = exp_16;
            frac_rd_16 = frac_16;
        end
    end

    assign FP16 = {sign_16, exp_rd_16, frac_rd_16};
endmodule
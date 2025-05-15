`timescale 1ns / 1ps

module FP16_to_FP32(
    input   wire    [15 : 0]    FP16,
    output  reg     [31 : 0]    FP32
    );

    wire                sign_16 = FP16[15];
    wire    [4 : 0]     exp_16 = FP16[14 : 10];
    wire    [9 : 0]     frac_16 = FP16[9 : 0];

    reg                 sign_32;
    reg     [7 : 0]     exp_32;
    reg     [22 : 0]    frac_32;

    always @(*) begin
        sign_32 = sign_16;
        if(exp_16 == {5{1'b1}}) begin
            exp_32 = {8{1'b1}};
            if(frac_16 == 10'b0) begin
                frac_32 = 23'b0;
            end
            else begin
                frac_32 = {1'b1, 22'b0};
            end
        end
        else if(exp_16 == 0) begin
            casex(frac_16)
                10'b1xxxxxxxxx: begin
                    exp_32 = 112;
                    frac_32 = {frac_16[8 : 0], 14'b0};
                end
                10'b01xxxxxxxx: begin
                    exp_32 = 111;
                    frac_32 = {frac_16[7 : 0], 15'b0};
                end
                10'b001xxxxxxx: begin
                    exp_32 = 110;
                    frac_32 = {frac_16[6 : 0], 16'b0};
                end
                10'b0001xxxxxx: begin
                    exp_32 = 109;
                    frac_32 = {frac_16[5 : 0], 17'b0};
                end
                10'b00001xxxxx: begin
                    exp_32 = 108;
                    frac_32 = {frac_16[4 : 0], 18'b0};
                end
                10'b000001xxxx: begin
                    exp_32 = 107;
                    frac_32 = {frac_16[3 : 0], 19'b0};
                end
                10'b0000001xxx: begin
                    exp_32 = 106;
                    frac_32 = {frac_16[2 : 0], 20'b0};
                end
                10'b00000001xx: begin
                    exp_32 = 105;
                    frac_32 = {frac_16[1 : 0], 21'b0};
                end
                10'b000000001x: begin
                    exp_32 = 104;
                    frac_32 = {frac_16[0], 22'b0};
                end
                10'b0000000001: begin
                    exp_32 = 103;
                    frac_32 = 23'b0;
                end
                default: begin
                    exp_32 = 8'b0;
                    frac_32 = 23'b0;
                end
            endcase
        end
        else begin
            exp_32 = (exp_16 - 15) + 127;
            frac_32 = {frac_16, {13'b0}}; 
        end
    end

    assign FP32 = {sign_32, exp_32, frac_32};
endmodule
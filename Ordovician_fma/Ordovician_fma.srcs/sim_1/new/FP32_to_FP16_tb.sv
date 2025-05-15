`timescale 1ns / 1ps

module FP32_to_FP16_tb(
    );
    logic   [31 : 0]    FP32;
    logic   [15 : 0]    FP16;

    FP32_to_FP16 FP32_to_FP16_tb(
        .FP32(FP32),
        .FP16(FP16)
    );

    initial begin
        FP32 = 32'h422247c9;        // 40.570102691650390625
        # 10;
        FP32 = 32'h38000000;        // 2e(-15)
        # 10
        FP32 = 32'h387fffff;        // (2-2e(-23))*2e(-15)
        # 10;
        FP32 = 32'h00400000;        // 2e(-127)
        # 10;
        FP32 = 32'h7f000000;        // 2e(127)
        # 10;
        FP32 = 32'h80000000;        // -0
        # 10;
        FP32 = 32'h7f810520;        // NaN
        # 10;
        FP32 = 32'h7f800000;        // inf
    end
endmodule
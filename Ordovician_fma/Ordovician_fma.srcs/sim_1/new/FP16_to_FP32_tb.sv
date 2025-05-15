`timescale 1ns / 1ps

module FP16_to_FP32_tb(
    );
    logic   [15 : 0]    FP16;
    logic   [31 : 0]    FP32;

    FP16_to_FP32 FP16_to_FP32_tb(
        .FP16(FP16),
        .FP32(FP32)
    );

    initial begin
        FP16 = 16'b0011_1100_0000_0000;     // 1
        # 10;
        FP16 = 16'b0000_1000_0000_0000;     // 2e(-14)
        # 10;
        FP16 = 16'b0000_0000_0000_0001;     // 2e(-24)
        # 10;
        FP16 = 16'b0111_1110_0000_0001;     // NaN
        # 10;
        FP16 = 16'b1000_0000_0000_0000;     // -0
    end
endmodule
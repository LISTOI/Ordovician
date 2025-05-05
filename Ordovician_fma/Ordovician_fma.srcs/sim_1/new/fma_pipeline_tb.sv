`timescale 1ns / 1ps

module fma_pipeline_tb(
    );
    logic               clk;
    logic               rst_n;
    logic               valid_in;
    logic   [31 : 0]    A_in;
    logic   [31 : 0]    B_in;
    logic   [31 : 0]    C_in;
    logic               valid_out;
    logic   [31 : 0]    F_out;

    fma_pipeline fma_pipeline_tb(
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .A_in(A_in),
        .B_in(B_in),
        .C_in(C_in),
        .valid_out(valid_out),
        .F_out(F_out)
    );

    initial begin
        rst_n = 0;
        valid_in = 0;
        # 9.9;
        rst_n = 1;
        valid_in = 1;
        A_in = 32'h00000000;
        B_in = 32'h3FC00000;
        C_in = 32'h00000000;
    end

    initial clk = 1;
    always #0.5 clk = ~clk;
endmodule

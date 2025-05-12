`timescale 1ns / 1ps
module WRITE_Matrix(
    input logic clk,
    input logic rstn,
    input logic writestart,
    output logic writedone,

    input logic [31:0] Matrix_C[0:3][0:7][0:7],

    input logic [1:0] MUL_valid,
    input logic [1:0] ADD_valid,
    input logic [1:0] Matrix_type
    );
    assign writedone = 1'b1;
endmodule

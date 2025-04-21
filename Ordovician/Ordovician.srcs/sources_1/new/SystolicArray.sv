`timescale 1ns / 1ps
module SystolicArray (
    input  logic        clk,
    input  logic        rstn,
    input  logic        calcstart,
    output logic        calcdone,
    input  logic [31:0] Matrix_A        [0:7][0:23],
    input  logic [31:0] Matrix_B        [0:7][0:23],
    input  logic [31:0] Matrix_C_input  [0:7][0: 7],
    output logic [31:0] Matrix_C_output [0:7][0: 7],
    input  logic [5 :0] MUL_valid,
    input  logic [5 :0] ADD_valid
);
endmodule
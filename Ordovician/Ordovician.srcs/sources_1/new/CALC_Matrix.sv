`timescale 1ns / 1ps
module CALC_Matrix(
    input  logic        clk,
    input  logic        rstn,
    input  logic        calcstart,
    output logic        calcdone,
    input  logic [31:0] Matrix_A        [0:3][0:7][0:23],
    input  logic [31:0] Matrix_B        [0:3][0:7][0:23],
    input  logic [31:0] Matrix_C_input  [0:3][0:7][0: 7],
    output logic [31:0] Matrix_C_output [0:3][0:7][0: 7],
    input  logic [5 :0] MUL_valid,
    input  logic [5 :0] ADD_valid,
    input  logic [1 :0] Matrix_type //0 : m8k16n32 1：m16k16n16 2：m32k16n8
    );
    logic [31:0] Matrix_A_input[0:3][0:7][0:23];
    logic [31:0] Matrix_B_input[0:3][0:7][0:23];
    logic calcdone1, calcdone2, calcdone3, calcdone4;
    //例化四个8*16的脉动阵列
    SystolicArray systolicarray1(
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone1),
        .Matrix_A(Matrix_A_input[0]),
        .Matrix_B(Matrix_B_input[0]),
        .Matrix_C_input(Matrix_C_input[0]),
        .Matrix_C_output(Matrix_C_output[0]),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid)
    );
    SystolicArray systolicarray2(
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone2),
        .Matrix_A(Matrix_A_input[1]),
        .Matrix_B(Matrix_B_input[1]),
        .Matrix_C_input(Matrix_C_input[1]),
        .Matrix_C_output(Matrix_C_output[1]),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid)
    );
    SystolicArray systolicarray3(
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone3),
        .Matrix_A(Matrix_A_input[2]),
        .Matrix_B(Matrix_B_input[2]),
        .Matrix_C_input(Matrix_C_input[2]),
        .Matrix_C_output(Matrix_C_output[2]),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid)
    );
    SystolicArray systolicarray4(
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone4),
        .Matrix_A(Matrix_A_input[3]),
        .Matrix_B(Matrix_B_input[3]),
        .Matrix_C_input(Matrix_C_input[3]),
        .Matrix_C_output(Matrix_C_output[3]),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid)
    );
    //将四个脉动阵列的完成信号进行或运算
    assign calcdone = calcdone1 | calcdone2 | calcdone3 | calcdone4;
    //将输入矩阵A和B进行选择，送入脉动阵列
    always @(*) begin
        case (Matrix_type)
            2'b00: begin
                Matrix_A_input[0] = Matrix_A[0];
                Matrix_A_input[1] = Matrix_A[0];
                Matrix_A_input[2] = Matrix_A[0];
                Matrix_A_input[3] = Matrix_A[0];

                Matrix_B_input[0] = Matrix_B[0];
                Matrix_B_input[1] = Matrix_B[1];
                Matrix_B_input[2] = Matrix_B[2];
                Matrix_B_input[3] = Matrix_B[3];
            end
            2'b01: begin
                Matrix_A_input[0] = Matrix_A[0];
                Matrix_A_input[1] = Matrix_A[0];
                Matrix_A_input[2] = Matrix_A[1];
                Matrix_A_input[3] = Matrix_A[1];
                
                Matrix_B_input[0] = Matrix_B[0];
                Matrix_B_input[1] = Matrix_B[1];
                Matrix_B_input[2] = Matrix_B[0];
                Matrix_B_input[3] = Matrix_B[1];
            end
            2'b10: begin
                Matrix_A_input[0] = Matrix_A[0];
                Matrix_A_input[1] = Matrix_A[1];
                Matrix_A_input[2] = Matrix_A[2];
                Matrix_A_input[3] = Matrix_A[3];
                
                Matrix_B_input[0] = Matrix_B[0];
                Matrix_B_input[1] = Matrix_B[0];
                Matrix_B_input[2] = Matrix_B[0];
                Matrix_B_input[3] = Matrix_B[0];
            end
            default: begin
                Matrix_A_input = '{default: '{default: '{default: 32'd0}}};
                Matrix_B_input = '{default: '{default: '{default: 32'd0}}};
            end
        endcase
    end
endmodule

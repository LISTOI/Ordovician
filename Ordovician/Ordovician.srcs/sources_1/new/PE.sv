`timescale 1ns / 1ps

module PE #(parameter WIDTH = 32)(
    input  logic              clk,
    input  logic              rstn,
    input  logic [WIDTH-1:0]  A_in,   // 输入A
    input  logic [WIDTH-1:0]  B_in,   // 输入B
    input  logic              C_load, // 是否加载初始C
    input  logic [WIDTH-1:0]  C_init, // 初始C输入
    output logic [WIDTH-1:0]  A_out,  // 向右输出A
    output logic [WIDTH-1:0]  B_out,  // 向下输出B
    output logic [WIDTH-1:0]  C_out,  // 输出累加值C
    input  logic [5:0]        MUL_valid, // 乘法精度（未用）
    input  logic [5:0]        ADD_valid  // 加法精度（未用）
);

    logic [WIDTH-1:0] A_reg, B_reg, C_reg;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            A_reg <= 0;
            B_reg <= 0;
            C_reg <= 0;
        end else begin
            A_reg <= A_in;                     // 保存A
            B_reg <= B_in;                     // 保存B
            if (C_load)
                C_reg <= C_init;               // 加载初值
            else
                C_reg <= C_reg + (A_reg * B_reg); // 执行乘加
        end
    end

    assign A_out = A_reg;
    assign B_out = B_reg;
    assign C_out = C_reg;

endmodule
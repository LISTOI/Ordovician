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
    input  logic [1:0]        MUL_valid, // 乘法精度
    input  logic [1:0]        ADD_valid  // 加法精度
);

    logic [WIDTH-1:0] A_reg, B_reg, C_reg;
    //浮点运算单元
    logic [WIDTH-1:0] C_fpu;
    //整形运算单元
    logic signed [7:0] A_alu, B_alu;
    logic signed [15:0] C_alu;
    logic signed [15:0] C_next;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            A_reg <= 0;
            B_reg <= 0;
            C_reg <= 0;
            C_alu <= 0;
            C_fpu <= 0;
            A_alu <= 0;
            B_alu <= 0;
        end else begin
            A_reg <= A_in;
            B_reg <= B_in;

            if (C_load) begin
                C_reg <= C_init;
                C_alu <= C_init[15:0];
            end else begin
                A_alu <= A_reg[7:0];
                B_alu <= B_reg[7:0];
                C_alu <= C_reg[15:0];

                // 执行乘加
                C_next = C_alu + (A_alu * B_alu);

                // 饱和处理（针对 int4 / int8）
                if (MUL_valid == 2'b01 && ADD_valid == 2'b01) begin // int8
                    if (C_next > 127)
                        C_alu <= 127;
                    else if (C_next < -128)
                        C_alu <= -128;
                    else
                        C_alu <= C_next;
                end else if (MUL_valid == 2'b00 && ADD_valid == 2'b00) begin // int4
                    if (C_next > 7)
                        C_alu <= 7;
                    else if (C_next < -8)
                        C_alu <= -8;
                    else
                        C_alu <= C_next;
                end else begin
                    C_alu <= C_next; // 无饱和
            end

            // 更新 C_reg 的低 16 位
                C_reg <= {C_reg[31:16], C_alu};
            end
        end
    end

    assign A_out = A_reg;
    assign B_out = B_reg;
    always_comb begin
        if((ADD_valid == 2'b00 || ADD_valid == 2'b01) && (MUL_valid == 2'b00 || MUL_valid == 2'b01))
            C_out = C_reg;
        else C_out = C_fpu;
    end
endmodule
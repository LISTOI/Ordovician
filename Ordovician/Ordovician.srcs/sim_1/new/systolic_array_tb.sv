`timescale 1ns / 1ps

module SystolicArray_tb;
    parameter ROW = 8;
    parameter COL = 8;
    parameter K   = 24;
    
    logic clk;
    logic rstn;
    logic calcstart;
    logic calcdone;

    logic [31:0] Matrix_A       [0:ROW-1][0:K-1];
    logic [31:0] Matrix_B       [0:K-1][0:COL-1];
    logic [31:0] Matrix_C_input [0:ROW-1][0:COL-1];
    logic [31:0] Matrix_C_output[0:ROW-1][0:COL-1];

    logic [5:0] MUL_valid;
    logic [5:0] ADD_valid;

    SystolicArray dut (
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone),
        .Matrix_A(Matrix_A),
        .Matrix_B(Matrix_B),
        .Matrix_C_input(Matrix_C_input),
        .Matrix_C_output(Matrix_C_output),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid)
    );

    // 生成时钟
    always #5 clk = ~clk;

    // 初始化矩阵输入
    task init_matrices;
        integer i, j;
        begin
            for (i = 0; i < ROW; i = i + 1)
                for (j = 0; j < K; j = j + 1)
                    Matrix_A[i][j] = i + j;

            for (i = 0; i < K; i = i + 1)
                for (j = 0; j < COL; j = j + 1)
                    Matrix_B[i][j] = i - j;

            for (i = 0; i < ROW; i = i + 1)
                for (j = 0; j < COL; j = j + 1)
                    Matrix_C_input[i][j] = 0;
        end
    endtask

    // 主测试流程
    initial begin
        clk = 0;
        rstn = 0;
        calcstart = 0;
        MUL_valid = 6'd0;
        ADD_valid = 6'd0;
        init_matrices();

        #20;
        rstn = 1;
        #10;
        calcstart = 1;
        #10;
        calcstart = 0;

        wait(calcdone);
        #10;

        // 打印输出结果
        $display("Matrix C Output:");
        for (int i = 0; i < ROW; i++) begin
            for (int j = 0; j < COL; j++) begin
                $write("%d ", Matrix_C_output[i][j]);
            end
            $display("");
        end

        $finish;
    end
endmodule
`timescale 1ns / 1ps
module SystolicArray (
    input  logic        clk,
    input  logic        rstn,
    input  logic        calcstart,
    output logic        calcdone,
    input  logic [31:0] Matrix_A        [0: 7][0:23], // 输入矩阵A，已填充气泡
    input  logic [31:0] Matrix_B        [0:23][0: 7], // 输入矩阵B，已填充气泡
    input  logic [31:0] Matrix_C_input  [0: 7][0: 7],  // 初始C矩阵
    output logic [31:0] Matrix_C_output [0: 7][0: 7],  // 输出C矩阵
    input  logic [5 :0] MUL_valid,
    input  logic [5 :0] ADD_valid
);

    localparam integer ROW = 8;
    localparam integer COL = 8;
    localparam integer K   = 24; // 含气泡后乘加深度

    logic [31:0] A_wire [0:ROW][0:COL]; // A方向流动线
    logic [31:0] B_wire [0:ROW][0:COL]; // B方向流动线
    logic [31:0] C_out_wire [0:ROW-1][0:COL-1]; // PE输出结果
    logic        C_load;

    genvar i, j;
    generate
        for (i = 0; i < ROW; i = i + 1) begin: row_loop
            for (j = 0; j < COL; j = j + 1) begin: col_loop
                PE pe_inst (
                    .clk(clk),
                    .rstn(rstn),
                    .A_in(A_wire[i][j]),
                    .B_in(B_wire[i][j]),
                    .C_load(C_load),
                    .C_init(Matrix_C_input[i][j]),
                    .A_out(A_wire[i][j+1]),
                    .B_out(B_wire[i+1][j]),
                    .C_out(C_out_wire[i][j]),
                    .MUL_valid(MUL_valid),
                    .ADD_valid(ADD_valid)
                );
            end
        end
    endgenerate

    logic [31:0] step_cnt;// 步数计数器，设置为32位防止比较时位宽不一致
    typedef enum logic [1:0] {
        IDLE, LOAD, CALC, DONE
    } state_t;
    state_t state, next_state;

    // 状态跳转逻辑
    always_ff @(posedge clk) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // 状态机定义
    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (calcstart) next_state = LOAD;
            LOAD:  next_state = CALC;
            CALC:  if (step_cnt == K + ROW - 1) next_state = DONE;
            DONE:  next_state = DONE; // 永久保持DONE，确保输出稳定
        endcase
    end

    // 步数计数器（控制A/B流动）
    always_ff @(posedge clk) begin
        if (!rstn)
            step_cnt <= 0;
        else if (state == CALC)
            step_cnt <= step_cnt + 1;
        else
            step_cnt <= 0;
    end

    assign C_load = (state == LOAD);

    integer m, n;

    // 输入数据沿A、B轴灌入
    always_ff @(posedge clk) begin
        if (!rstn) begin
            for (m = 0; m < ROW; m = m + 1)
                A_wire[m][0] <= 0;
            for (n = 0; n < COL; n = n + 1)
                B_wire[0][n] <= 0;
        end else if (state == CALC) begin
            for (m = 0; m < ROW; m = m + 1)
                A_wire[m][0] <= (step_cnt < K) ? Matrix_A[m][step_cnt] : 0;
            for (n = 0; n < COL; n = n + 1)
                B_wire[0][n] <= (step_cnt < K) ? Matrix_B[step_cnt][n] : 0;
        end else begin
            for (m = 0; m < ROW; m = m + 1)
                A_wire[m][0] <= 0;
            for (n = 0; n < COL; n = n + 1)
                B_wire[0][n] <= 0;
        end
    end

    // 输出矩阵C取自各PE的C寄存器
    always_ff @(posedge clk) begin
        if (!rstn) begin
            for (m = 0; m < ROW; m = m + 1)
                for (n = 0; n < COL; n = n + 1)
                    Matrix_C_output[m][n] <= 0;
        end else if (state == DONE) begin
            for (m = 0; m < ROW; m = m + 1)
                for (n = 0; n < COL; n = n + 1)
                    Matrix_C_output[m][n] <= C_out_wire[m][n];
        end
    end

    assign calcdone = (state == DONE);

endmodule

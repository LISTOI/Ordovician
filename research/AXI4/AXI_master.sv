`timescale 1ns / 1ps

module AXI_master (
    input  logic        clk,
    input  logic        rstn,

    // AXI4 Write Data Channel
    output logic [31:0] wdata,
    output logic        wvalid,
    input  logic        wready,

    // AXI4 Write Response Channel
    input  logic [1:0]  bresp,
    input  logic        bvalid,
    output logic        bready,

    // User Interface
    input  logic [31:0] send_data,     // 要发送的数据
    input  logic        data_valid,    // 数据有效信号
    output logic        data_ready     // 准备好接收新数据
);

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,           // 等待用户数据
        DATA_TRANSFER,  // 数据传输阶段
        WAIT_RESPONSE   // 等待响应确认
    } state_t;

    state_t current_state, next_state;

    // 数据寄存器
    logic [31:0] data_buffer;

    // 状态转移逻辑
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
            data_buffer   <= '0;
        end else begin
            current_state <= next_state;
            // 缓冲用户数据
            if (data_valid && data_ready) begin
                data_buffer <= send_data;
            end
        end
    end

    // 下一状态逻辑
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (data_valid) begin
                    next_state = DATA_TRANSFER;
                end
            end

            DATA_TRANSFER: begin
                if (wvalid && wready) begin
                    next_state = WAIT_RESPONSE;
                end
            end

            WAIT_RESPONSE: begin
                if (bvalid && bready) begin
                    next_state = data_valid ? DATA_TRANSFER : IDLE;
                end
            end
        endcase
    end

    // 输出逻辑
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wvalid    <= 1'b0;
            bready    <= 1'b0;
            data_ready<= 1'b0;
            wdata     <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    wvalid    <= 1'b0;
                    bready    <= 1'b0;
                    data_ready<= 1'b1;  // 准备好接收用户数据
                    wdata     <= send_data;
                end

                DATA_TRANSFER: begin
                    wvalid    <= 1'b1;
                    data_ready<= 1'b0;
                    // 保持数据稳定
                    if (!wvalid || wready) begin
                        wdata <= data_buffer;
                    end
                end

                WAIT_RESPONSE: begin
                    wvalid    <= 1'b0;
                    bready    <= 1'b1;
                    // 准备下一数据
                    if (bvalid && bready) begin
                        data_ready <= 1'b1;
                        wdata      <= send_data;
                    end
                end
            endcase
        end
    end

    // 协议检查断言
    always @(posedge clk) begin
        if (wvalid && !$isunknown(wready)) begin
            assert(wvalid |-> !$isunknown(wdata)) 
                else $error("Data undefined when valid");
        end

        if (bvalid) begin
            assert(bready |-> !$isunknown(bresp))
                else $error("Response undefined");
        end
    end

endmodule
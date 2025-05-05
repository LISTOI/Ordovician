`timescale 1ns / 1ps
module Ordovician_top(
    input  clk,
    input  rstn,
    input  readstart,
    output logic done
);
    logic [31:0] Matrix_A        [0:3][0: 7][0:23];
    logic [31:0] Matrix_B        [0:3][0:23][0: 7];
    logic [31:0] Matrix_C_input  [0:3][0: 7][0: 7];
    logic [31:0] Matrix_C_output [0:3][0: 7][0: 7];
    logic [5 :0] MUL_valid;
    logic [5 :0] ADD_valid;
    logic [1 :0] Matrix_type; //0 : m8k16n32 1：m16k16n16 2：m32k16n8
    logic        readdone;
    logic        calcstart;
    logic        calcdone;
    logic        writestart;
    logic        writedone;

    //例化读模块，写模块与处理模块
    //读模块是读入外部数据
    READ_Matrix read_matrix(
        .clk(clk),
        .rstn(rstn),
        .readstart(readstart),
        .readdone(readdone),
        .Matrix_A(Matrix_A),
        .Matrix_B(Matrix_B),
        .Matrix_C(Matrix_C_input),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid),
        .Matrix_type(Matrix_type)
    );
    CALC_Matrix calc_matrix(
        .clk(clk),
        .rstn(rstn),
        .calcstart(calcstart),
        .calcdone(calcdone),
        .Matrix_A(Matrix_A),
        .Matrix_B(Matrix_B),
        .Matrix_C_input(Matrix_C_input),
        .Matrix_C_output(Matrix_C_output),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid),
        .Matrix_type(Matrix_type)
    );
    WRITE_Matrix write_matrix(
        .clk(clk),
        .rstn(rstn),
        .writestart(writestart),
        .writedone(writedone),
        .Matrix_C(Matrix_C_output),
        //.MUL_valid(MUL_valid),
        //.ADD_valid(ADD_valid),
        .Matrix_type(Matrix_type)
    );

    //顶层状态机与其控制逻辑
    localparam  IDLE=2'b00,
                READ=2'b01,
                CALC=2'b10,
                WRITE=2'b11;
    logic [1:0] state;
    logic [1:0] next_state;
    always @(posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    always @(*) begin
        case (state)
            IDLE: begin
                if (readstart) begin
                    next_state = READ;
                end else begin
                    next_state = IDLE;
                end
            end
            READ: begin
                if(readdone) begin
                    next_state = CALC;
                end else begin
                    next_state = READ;
                end
            end
            CALC: begin
                if (calcdone) begin
                    next_state = WRITE;
                end else begin
                    next_state = CALC;
                end
            end
            WRITE: begin
                if (writedone) begin
                    next_state = IDLE;
                end else begin
                    next_state = WRITE;
                end
            end
            default begin
                next_state = IDLE;
            end
        endcase
    end
    always @(*) begin
        case(state)
        IDLE: begin
            calcstart = 1'b0;
            writestart = 1'b0;
            done = 1'b1;    
        end
        READ: begin
            calcstart = 1'b0;
            writestart = 1'b0;
            done = 1'b0;    
        end
        CALC: begin
            calcstart = 1'b1;
            writestart = 1'b0;
            done = 1'b0;    
        end
        WRITE: begin
            calcstart = 1'b0;
            writestart = 1'b1;
            done = 1'b0;    
        end
        default: begin
            calcstart = 1'b0;
            writestart = 1'b0;
            done = 1'b0;    
        end
        endcase
    end
endmodule

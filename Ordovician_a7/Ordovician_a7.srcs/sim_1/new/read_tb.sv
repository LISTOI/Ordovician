`timescale 1ns / 1ps

module read_tb;

    // Testbench signals
    logic clk;
    logic rstn;
    logic readstart;
    logic readdone;
    logic [31:0] Matrix_A[0:3][0:7][0:22];
    logic [31:0] Matrix_B[0:3][0:22][0:7];
    logic [31:0] Matrix_C[0:3][0:7][0:7];
    logic [1:0] MUL_valid;
    logic [1:0] ADD_valid;
    logic [1:0] Matrix_type;

    // DUT instantiation
    READ_Matrix dut (
        .clk(clk),
        .rstn(rstn),
        .readstart(readstart),
        .readdone(readdone),
        .Matrix_A(Matrix_A),
        .Matrix_B(Matrix_B),
        .Matrix_C(Matrix_C),
        .MUL_valid(MUL_valid),
        .ADD_valid(ADD_valid),
        .Matrix_type(Matrix_type)
    );

    // Clock generation
    initial begin
        clk = 1;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Reset and initial conditions
    initial begin
        rstn = 0;
        readstart = 0;

        // Apply reset
        #20 rstn = 1;
    end

    // Test case 1: Normal operation
    initial begin
        // Wait for reset to complete
        wait(rstn == 1);
        @(posedge clk);

        // Start reading
        readstart = 1;
        @(posedge clk);
        readstart = 0;

        // Wait for readdone
        wait(readdone == 1);
        @(posedge clk);

        $display("Test Case 1: Normal operation passed!");
        $finish;
    end

endmodule
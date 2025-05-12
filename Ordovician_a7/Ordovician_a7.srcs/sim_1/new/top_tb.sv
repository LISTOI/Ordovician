`timescale 1ns / 1ps

module top_tb();

    logic clk;
    logic rstn;
    logic readstart;
    logic done;

    Ordovician_top top_tb(
        .clk(clk),
        .rstn(rstn),
        .readstart(readstart),
        .done(done)
    );

    initial begin
        clk = 1;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    initial begin
        rstn = 0;
        readstart = 0;

        // Apply reset
        #20 rstn = 1;
    end

    initial begin
        // Wait for reset to complete
        wait(rstn == 1);
        @(posedge clk);

        // Start reading
        readstart = 1;
        @(posedge clk);
        readstart = 0;

        #20
        
        // Wait for readdone
        wait(done == 1);
        @(posedge clk);

        $finish;
    end
endmodule

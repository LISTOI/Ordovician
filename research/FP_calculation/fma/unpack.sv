`timescale 1ns / 1ps

module unpack #(
    parameter FP = 32,
    parameter FPexp = 8,
    parameter FPfra = 23,
    )(
    input   wire    [FP:0]      a,
    output  reg     [FPexp:0]   a_e,
    output  reg     [FPfra:0]   a_f,
    // special case
    output  wire                nan,
    output  wire                inf,
    // stb refers to strobe(signal is ready)
    // ack refers to acknowledgment(signal is received)
    input   wire                stb,
    output  wire                ack,
    );
endmodule
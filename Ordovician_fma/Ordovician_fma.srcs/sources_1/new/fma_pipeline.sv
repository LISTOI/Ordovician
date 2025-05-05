`timescale 1ns / 1ps

module fma_pipeline #(
    parameter FP = 32,
    parameter FPexp = 8,
    parameter FPfrac = 23
    )(
    input   wire                    clk,
    input   wire                    rst_n,
    input   wire                    valid_in,
    input   wire    [FP - 1 : 0]    A_in, 
    input   wire    [FP - 1 : 0]    B_in,
    input   wire    [FP - 1 : 0]    C_in,
    output  wire                    valid_out,
    output  wire    [FP - 1 : 0]    F_out
    );

    // Stage 1: Decode
    reg valid_s1;
    
    // Pipeline registers for stage 1
    reg                     signA_s1, signB_s1, signC_s1;
    reg [FPexp - 1 : 0]     expA_s1, expB_s1, expC_s1;
    reg [FPfrac : 0]        fracA_s1, fracB_s1, fracC_s1;   // An extra bit for the integer part

    // Break each float into sign, exponent, fraction
    wire                        signA_in = A_in[FP - 1];
    wire    [FPexp - 1 : 0]     expA_in = A_in[FPfrac + FPexp - 1 : FPfrac];
    wire    [FPfrac - 1 : 0]    fracA_in = A_in[FPfrac - 1 : 0];
    wire                        signB_in = B_in[FP - 1];
    wire    [FPexp - 1 : 0]     expB_in = B_in[FPfrac + FPexp - 1 : FPfrac];
    wire    [FPfrac - 1 : 0]    fracB_in = B_in[FPfrac - 1 : 0];
    wire                        signC_in = C_in[FP - 1];
    wire    [FPexp - 1 : 0]     expC_in = C_in[FPfrac + FPexp - 1 : FPfrac];
    wire    [FPfrac - 1 : 0]    fracC_in = C_in[FPfrac - 1 : 0];

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s1 <= 1'b0;
            signA_s1 <= 1'b0; expA_s1 <= {(FPexp){1'b0}}; fracA_s1 <= {(FPfrac + 1){1'b0}};
            signB_s1 <= 1'b0; expB_s1 <= {(FPexp){1'b0}}; fracB_s1 <= {(FPfrac + 1){1'b0}};
            signC_s1 <= 1'b0; expC_s1 <= {(FPexp){1'b0}}; fracC_s1 <= {(FPfrac + 1){1'b0}};
        end
        else begin
            valid_s1 <= valid_in;

            signA_s1 <= signA_in;
            expA_s1 <= expA_in;
            fracA_s1 <= (expA_in == 0) ? {1'b0, fracA_in} : {1'b1, fracA_in};

            signB_s1 <= signB_in;
            expB_s1 <= expB_in;
            fracB_s1 <= (expB_in == 0) ? {1'b0, fracB_in} : {1'b1, fracB_in};

            signC_s1 <= signC_in;
            expC_s1 <= expC_in;
            fracC_s1 <= (expC_in == 0) ? {1'b0, fracC_in} : {1'b1, fracC_in};
        end
    end

    // Stage 2: Multiply A and B
    reg valid_s2;

    // Pipeline registers for stage 2
    reg                                 signAB_s2;
    reg [FPexp + 1 : 0]                 expAB_s2;   // Bit width for exponent sum
    reg [((FPfrac + 1) << 1) - 1 : 0]   prodAB_s2;  // Bit width for fraction product
    reg                                 signC_s2;
    reg [FPexp - 1 : 0]                 expC_s2;
    reg [FPfrac : 0]                    fracC_s2;

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s2 <= 1'b0;

            signAB_s2 <= 1'b0;
            expAB_s2 <= {(FPexp + 2){1'b0}}; prodAB_s2 <= {((FPfrac + 1) << 1){1'b0}};

            signC_s2 <= 1'b0;
            expC_s2 <= {(FPexp){1'b0}};
            fracC_s2 <= {(FPfrac + 1){1'b0}};
        end 
        else begin
            valid_s2 <= valid_s1;

            // Multiply sign
            signAB_s2 <= signA_s1 ^ signB_s1;

            // Add exponents
            expAB_s2 <= (expA_s1 + expB_s1) - ((1 << (FPexp - 1)) - 1);

            // Multiply fra
            prodAB_s2 <= fracA_s1 * fracB_s1;

            // Pass along C
            signC_s2 <= signC_s1;
            expC_s2 <= expC_s1;
            fracC_s2 <= fracC_s1;
        end
    end

    // Stage 3: Normalize product
    reg valid_s3;

    // Pipeline registers for stage 3
    reg                                 signAB_s3;
    reg [FPexp + 1 : 0]                 expAB_s3;
    reg [((FPfrac + 1) << 1) - 1 : 0]   prodAB_s3;
    reg                                 signC_s3;
    reg [FPexp - 1 : 0]                 expC_s3;
    reg [FPfrac : 0]                    fracC_s3;

    // Normlized product
    reg [FPexp + 1 : 0]                 normexp_s2;
    reg [((FPfrac + 1) << 1) - 1 : 0]   normprod_s2;
    wire                                leadingbit = prodAB_s2[((FPfrac + 1) << 1) - 1]; 

    always @(*) begin
        // If the leading bit is set, we have an overflow
        if(leadingbit == 1'b1) begin
            // Shift right by 1
            normexp_s2 = expAB_s2 + 1;
            normprod_s2 = prodAB_s2 >> 1;
        end
        else begin
            normexp_s2 = expAB_s2;
            normprod_s2 = prodAB_s2;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s3 <= 1'b0;
            signAB_s3 <= 1'b0;
            expAB_s3 <= {(FPexp << 1){1'b0}};
            prodAB_s3 <= {((FPfrac + 1) << 1){1'b0}};
            signC_s3 <= 1'b0;
            expC_s3 <= {(FPexp){1'b0}};
            fracC_s3 <= {(FPfrac + 1){1'b0}};
        end
        else begin
            valid_s3 <= valid_s2;
            signAB_s3 <= signAB_s2;
            expAB_s3 <= normexp_s2;
            prodAB_s3 <= normprod_s2;
        end
    end

    // Stage 4: Add product and C
    reg valid_s4;

    // Pipeline registers for stage 3
    reg                 sign_s4;
    reg [FP - 1: 0]     sum_s4; 

    // Round product
    wire [FPexp - 1 : 0]    finalexpAB_s3 = (expAB_s3 >= (1 << FPexp)) ? {(FPexp){1'b1}} : ((expAB_s3 < 0) ? {(FPexp){1'b0}} : expAB_s3[FPexp - 1 : 0]);
    wire [FPfrac : 0]       finalprodAB_s3 = prodAB_s3[(FPfrac << 1) : FPfrac];

    // Compare expAB_s3 and expC_s3 to align them
    reg [FPexp - 1 : 0]     bigexp, smallexp;
    reg [FPfrac : 0]        bigfrac, smallfrac;
    reg                     bigsign, smallsign;

    always @(*) begin
        if(finalexpAB_s3 > expC_s3) begin
            bigexp = finalexpAB_s3;
            bigfrac = finalprodAB_s3;
            bigsign = signAB_s3;
            smallexp = expC_s3;
            smallfrac = fracC_s3;
            smallsign = signC_s3;
        end
        else begin
            bigexp = expC_s3;
            bigfrac = fracC_s3;
            bigsign = signC_s3;
            smallexp = finalexpAB_s3;
            smallfrac = finalprodAB_s3;
            smallsign = signAB_s3;
        end
    end

    // Exponent difference
    wire [FPexp - 1 : 0]    expdiff = bigexp - smallexp;

    // Shift the smaller fraction
    wire [FPfrac : 0]       alignedsmall = (expdiff >= (FPfrac + 1)) ? {(FPfrac){1'b0}} : (smallfrac >> expdiff);

    // Add or subtract
    wire                    signdiff = bigsign ^ smallsign;
    reg [FPfrac + 1 : 0]    fracsum;

    always @(*) begin
        // Subtract
        if(signdiff) begin
            if(bigfrac >= alignedsmall) begin
                fracsum = bigfrac - alignedsmall;
                sign_s4 = bigsign;
            end
            else begin
                fracsum = alignedsmall - bigfrac;
                sign_s4 = ~bigsign;
            end
        end
        // Add
        else begin
            fracsum = bigfrac + alignedsmall;
            sign_s4 = bigsign;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s4 <= 1'b0;
            sum_s4 <= {(FP){1'b0}};
        end
        else begin
            valid_s4 <= valid_s3;
            sum_s4 <= {sign_s4, bigexp, fracsum[FPfrac - 1 : 0]};

            signC_s3 <= sign_s4;
            expC_s3 <= bigexp;
            fracC_s3 <= fracsum[FPfrac : 0];
        end
    end

    // Stage 5: Normalize & Round
    reg                 valid_s5;
    reg [FP - 1 : 0]    out_s5;

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s5 <= 1'b0;
            out_s5 <= {(FP){1'b0}};
        end
        else begin
            valid_s5 <= valid_s4;
            out_s5 <= sum_s4;
        end
    end

    assign valid_out = valid_s5;
    assign F_out = out_s5;

endmodule
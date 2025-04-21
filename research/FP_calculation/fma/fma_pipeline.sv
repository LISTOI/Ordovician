`timescale 1ns / 1ps

module fma_pipeline #(
    parameter FP = 32,
    parameter FPexp = 8,
    parameter FPfra = 23,
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
    reg [FP - 1 : 0]    A_s1, B_s1, C_s1;
    reg                 valid_s1;

    // Break each float into sign, exponent, fraction
    wire                        signA_in = A_in[FP - 1];
    wire    [FPexp - 1 : 0]     expA_in = A_in[FPfra + FPexp - 1 : FPfra];
    wire    [FPfra - 1 : 0]     fracA_in = A_in[FPfra - 1 : 0];
    wire                        signB_in = B_in[FP - 1];
    wire    [FPexp - 1 : 0]     expB_in = B_in[FPfra + FPexp - 1 : FPfra];
    wire    [FPfra - 1 : 0]     fracB_in = B_in[FPfra - 1 : 0];
    wire                        signC_in = C_in[FP - 1];
    wire    [FPexp - 1 : 0]     expC_in = C_in[FPfra + FPexp - 1 : FPfra];
    wire    [FPfra - 1 : 0]     fracC_in = C_in[FPfra - 1 : 0];

    // Pipeline registers for stage 1
    reg                     signA_s1, signB_s1, signC_s1;
    reg [FPexp - 1 : 0]     expA_s1, expB_s1, expC_s1;
    reg [FPfra : 0]         fracA_s1, fracB_s1, fracC_s1;   // 1 extra bit for the integer part

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s1 <= 1'b0;
            signA_s1 <= 1'b0; expA_s1 <= {(FPexp){1'b0}}; fracA_s1 <= {(FPfra + 1){1'b0}};
            signB_s1 <= 1'b0; expB_s1 <= {(FPexp){1'b0}}; fracB_s1 <= {(FPfra + 1){1'b0}};
            signC_s1 <= 1'b0; expC_s1 <= {(FPexp){1'b0}}; fracC_s1 <= {(FPfra + 1){1'b0}};
        end 
        else begin
            valid_s1 <= valid_in;
            
            signA_s1 <= signA_in;
            expA_s1  <= expA_in;
            fracA_s1 <= (expA_in == 0) ? {1'b0, fracA_in} : {1'b1, fracA_in};

            signB_s1 <= signB_in;
            expB_s1  <= expB_in;
            fracB_s1 <= (expB_in == 0) ? {1'b0, fracB_in} : {1'b1, fracB_in};

            signC_s1 <= signC_in;
            expC_s1  <= expC_in;
            fracC_s1 <= (expC_in == 0) ? {1'b0, fracC_in} : {1'b1, fracC_in};
        end
    end

    // Stage 2: Multiply A and B
    reg valid_s2;

    // Pipeline registers for stage 2
    reg                                 signAB_s2;
    reg [(FPexp << 1) - 1 : 0]          expAB_s2;   // bit width for exponent sum
    reg [((FPfra + 1) << 1) - 1 : 0]    prodAB_s2;  // bit width for fraction product
    reg                                 signC_s2;
    reg [FPexp - 1 : 0]                 expC_s2;
    reg [FPfra : 0]                     fracC_s2;

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s2 <= 1'b0;

            signAB_s2 <= 1'b0;
            expAB_s2 <= {(FPexp << 1){1'b0}}; prodAB_s2 <= {((FPfra + 1) << 1){1'b0}};

            signC_s2 <= 1'b0;
            expC_s2 <= {(FPexp){1'b0}};
            fracC_s2 <= {(FPfra + 1){1'b0}};
        end 
        else begin
            valid_s2 <= valid_s1;

            // Multiply sign
            signAB_s2 <= signA_s1 ^ signB_s1;

            // Add exponents
            expAB_s2 <= (expA_s1 + expB_s1) - (1 << FPexp);

            // Multiply fra
            prodAB_s2 <= fracA_s1 * fracB_s1;

            // Pass along C
            signC_s2 <= signC_s1;
            expC_s2 <= expC_s1;
            fracC_s2 <= fracC_s1;
        end
    end

    // Stage 3: Normalize product & Align C
    reg valid_s3;

    // Pipeline registers for stage 3
    reg                                 signAB_s3;
    reg [(FPexp << 1) - 1 : 0]          expAB_s3;
    reg [((FPfra + 1) << 1) - 1 : 0]    prodAB_s3;
    reg                                 signC_s3;
    reg [FPexp - 1 : 0]                 expC_s3;
    reg [FPfra : 0]                     fracC_s3;

    // Normlized product
    reg [(FPexp << 1) - 1 : 0]          normExp_s2;
    reg [((FPfra + 1) << 1) - 1 : 0]    normProd_s2;
    wire                                leadingBit = prodAB_s2[47]; // if the leading bit is set, we have an overflow

    always @(*) begin
        if(leadingBit == 1'b1) begin
            // shift right by 1
            normProd_s2 = prod_s2 >> 1;
            normExp_s2  = expAB_s2 + 1;
        end
        else begin
            normProd_s2 = prod_s2;
            normExp_s2  = expAB_s2;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s3   <= 1'b0;
            signAB_s3  <= 1'b0;
            expAB_s3   <= 16'd0;
            prod_s3    <= 48'd0;
            signC_s3   <= 1'b0;
            expC_s3    <= 8'd0;
            mantC_s3   <= 24'd0;
        end else begin
            valid_s3   <= valid_s2;
            signAB_s3  <= signAB_s2;
            expAB_s3   <= normExp_s2;
            prod_s3    <= normProd_s2;

            signC_s3   <= signC_s2;
            expC_s3    <= expC_s2;
            mantC_s3   <= mantC_s2;
        end
    end

    // Stage 4: Add product and C
    // We must compare expAB_s3 vs expC_s3 to align them if needed.
    // For simplicity, assume expAB_s3 is in the range of single-precision after stage 3.

    reg                 valid_s4;

    // Pipeline registers for stage 3
    reg                 sign_s4;
    reg [FP - 1 : 0]    addResult_s4; 

    // Convert product to a 24-bit mant (with leftover bits for fraction)
    wire [7:0] finalExpAB_s3 = (expAB_s3 > 255) ? 8'hFF : 
                               (expAB_s3 < 0)   ? 8'h00 : expAB_s3[7:0];

    // "mantProd" is top 24 bits of the 48-bit product, for the integer portion
    wire [23:0] mantProd_s3 = prod_s3[46:23]; // ignoring lower fraction bits for simplicity

    // Align the smaller exponent’s mantissa
    reg [7:0]  biggerExp;
    reg [7:0]  smallerExp;
    reg [23:0] biggerMant;
    reg [23:0] smallerMant;
    reg        biggerSign, smallerSign;

    always @(*) begin
        if(finalExpAB_s3 > expC_s3) begin
            biggerExp    = finalExpAB_s3;
            biggerMant   = mantProd_s3;
            biggerSign   = signAB_s3;
            smallerExp   = expC_s3;
            smallerMant  = mantC_s3;
            smallerSign  = signC_s3;
        end else begin
            biggerExp    = expC_s3;
            biggerMant   = mantC_s3;
            biggerSign   = signC_s3;
            smallerExp   = finalExpAB_s3;
            smallerMant  = mantProd_s3;
            smallerSign  = signAB_s3;
        end
    end

    // Exponent difference
    wire    [FPexp - 1 : 0] expDiff = biggerExp - smallerExp;

    // Shift the smaller fraction
    wire    [FPfra : 0] alignedSmaller = (expDiff >= 24) ? 24'd0 : (smallerMant >> expDiff);

    // Add or subtract
    wire                signAddDiff = biggerSign ^ smallerSign;
    reg [FPfra + 1 : 0] mantSum;

    always @(*) begin
        // Subtract
        if(signAddDiff) begin
            if(biggerMant >= alignedSmaller) begin
                mantSum = biggerMant - alignedSmaller;
                sign_s4 = biggerSign;
            end
            else begin
                mantSum = alignedSmaller - biggerMant;
                sign_s4 = ~biggerSign;
            end
        end
        // Add
        else begin
            mantSum = biggerMant + alignedSmaller;
            sign_s4 = biggerSign;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s4     <= 1'b0;
            addResult_s4 <= 32'h0;
        end
        else begin
            valid_s4 <= valid_s3;
            // Combine sign_s4, biggerExp, mantSum => float
            addResult_s4 <= {sign_s4, biggerExp, mantSum[22:0]};
        end
    end

    // Stage 5: Normalize & Round
    reg                 valid_s5;
    reg [FP - 1 : 0]    fOut_s5;

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s5 <= 1'b0;
            fOut_s5  <= 32'b0;
        end
        else begin
            valid_s5 <= valid_s4;
            fOut_s5  <= addResult_s4;
        end
    end

    assign valid_out = valid_s5;
    assign F_out = fOut_s5;

endmodule

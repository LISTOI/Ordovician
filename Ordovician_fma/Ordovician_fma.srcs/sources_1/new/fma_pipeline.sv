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

    // Stage 1: Unpack
    reg valid_s1;
    
    // Pipeline registers for stage 1
    reg                     signA_s1, signB_s1, signC_s1;
    reg [FPexp - 1 : 0]     expA_s1, expB_s1, expC_s1;
    reg [FPfrac : 0]        fracA_s1, fracB_s1, fracC_s1;   // An extra bit for the integer part

    // Unpack each float into sign, exponent, fraction
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
            expA_s1 <= (expA_in == 0) ? 1 : expA_in;
            fracA_s1 <= (expA_in == 0) ? {1'b0, fracA_in} : {1'b1, fracA_in};

            signB_s1 <= signB_in;
            expB_s1 <= (expB_in == 0) ? 1 : expB_in;
            fracB_s1 <= (expB_in == 0) ? {1'b0, fracB_in} : {1'b1, fracB_in};

            signC_s1 <= signC_in;
            expC_s1 <= (expC_in == 0) ? 1 : expC_in;
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
            expAB_s2 <= ((&expA_s1) | (&expB_s1)) ? ({(FPexp){1'b1}}) : (({{2'b0}, expA_s1} + {{2'b0}, expB_s1}) - ((1 << (FPexp - 1)) - 1));

            // Multiply frac
            prodAB_s2 <= {{(FPfrac + 1){1'b0}}, fracA_s1} * {{(FPfrac + 1){1'b0}}, fracB_s1};

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
    reg [FPexp + 1 : 0]                 expC_s3;
    reg [((FPfrac + 1) << 1) - 1 : 0]   fracC_s3;

    // Normlized product
    reg [FPexp + 1 : 0]                 expAB_norm;
    reg [((FPfrac + 1) << 1) - 1 : 0]   prodAB_norm;

    always @(*) begin
        // If the leading bit is set, we have an overflow
        if(prodAB_s2 == 0) begin
            expAB_norm = {(FPexp + 2){1'b0}};
            prodAB_norm = {((FPfrac + 1) << 1){1'b0}};
        end
        else begin
            if(prodAB_s2[((FPfrac + 1) << 1) - 1] == 1'b1) begin
                // Shift right by 1
                expAB_norm = expAB_s2 + 1;
                prodAB_norm = prodAB_s2 >> 1;
            end
            else begin
                expAB_norm = expAB_s2;
                prodAB_norm = prodAB_s2;
            end
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s3 <= 1'b0;

            signAB_s3 <= 1'b0;
            expAB_s3 <= {(FPexp + 2){1'b0}};
            prodAB_s3 <= {((FPfrac + 1) << 1){1'b0}};

            signC_s3 <= 1'b0;
            expC_s3 <= {(FPexp + 2){1'b0}};
            fracC_s3 <= {((FPfrac + 1) << 1){1'b0}};
        end
        else begin
            valid_s3 <= valid_s2;

            // Pass along A * B
            signAB_s3 <= signAB_s2;
            expAB_s3 <= expAB_norm;
            prodAB_s3 <= prodAB_norm;
        end
    end

    // Stage 4: Add product and C & Normlize sum
    reg valid_s4;

    // Pipeline registers for stage 4
    reg                                 sign_s4;
    reg [FPexp + 1 : 0]                 exp_s4;
    reg [((FPfrac + 1) << 1) - 1 : 0]   frac_s4;

    // Compare expAB_s3 and expC_s3 to align them
    reg                                 sign_big, sign_small;
    reg [FPexp + 1 : 0]                 exp_big, exp_small;
    reg [((FPfrac + 1) << 1) - 1 : 0]   frac_big, frac_small;
    
    always @(*) begin
        if($signed(expAB_s3) > $signed(expC_s3)) begin
            sign_big = signAB_s3;
            exp_big = expAB_s3;
            frac_big = prodAB_s3;

            sign_small = signC_s3;
            exp_small = expC_s3;
            frac_small = fracC_s3;
        end
        else begin
            sign_big = signC_s3;
            exp_big = expC_s3;
            frac_big = fracC_s3;

            sign_small = signAB_s3;
            exp_small = expAB_s3;
            frac_small = prodAB_s3;
        end
    end

    // Exponent difference
    wire [FPexp + 1 : 0]    exp_diff = exp_big - exp_small;

    // Align the smaller fraction
    wire [((FPfrac + 1) << 1) - 1 : 0]  frac_aligned = frac_small >> exp_diff;

    // Add or subtract
    reg                                 sign_sum;
    reg [((FPfrac + 1) << 1) - 1 : 0]   frac_sum;

    always @(*) begin
        // Subtract
        if(sign_big ^ sign_small) begin
            if(frac_big >= frac_aligned) begin
                sign_sum = sign_big;
                frac_sum = frac_big - frac_aligned;
            end
            else begin
                sign_sum = ~sign_big;
                frac_sum = frac_aligned - frac_big;
            end
        end
        // Add
        else begin
            sign_sum = sign_big;
            frac_sum = frac_big + frac_aligned;
        end
    end

    // Normlized sum
    reg [FPexp + 1 : 0]                 exp_norm;
    reg [((FPfrac + 1) << 1) - 1 : 0]   frac_norm;

    always @(*) begin
        if(frac_sum[((FPfrac + 1) << 1) - 1] == 1'b1) begin
            exp_norm = exp_big + 1;
            frac_norm = frac_sum >> 1;
        end
        else begin
            exp_norm = exp_big;
            frac_norm = frac_sum;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s4 <= 1'b0;

            sign_s4 <= 1'b0;
            exp_s4 <= {(FPexp + 2){1'b0}};
            frac_s4 <= {((FPfrac + 1) << 1){1'b0}};
        end
        else begin
            valid_s4 <= valid_s3;

            sign_s4 <= sign_sum;
            exp_s4 <= exp_norm;
            frac_s4 <= frac_norm;

            // Forwarding path of C
            if(valid_s3) begin
                signC_s3 <= sign_sum;
                expC_s3 <= exp_norm;
                fracC_s3 <= frac_norm;
            end
            else begin
                signC_s3 <= signC_s2;
                expC_s3 <= {{2'b0}, expC_s2};
                fracC_s3 <= {{1'b0}, fracC_s2, {(FPfrac){1'b0}}};
            end
        end
    end

    // Stage 5: Round & Pack
    reg                 valid_s5;
    reg [FP - 1 : 0]    out_s5;

    // Round sum
    reg [FPexp - 1 : 0]     exp_final;
    reg [FPfrac - 1 : 0]    frac_final;

    always @(*) begin
        if(exp_s4[FPexp + 1]) begin
            exp_final = {(FPexp){1'b0}};
            frac_final = {(FPfrac){1'b0}};
        end
        else if(exp_s4[FPexp] | (&exp_s4[FPexp - 1 : 0])) begin
            exp_final = {(FPexp){1'b1}};
            frac_final = {(FPfrac){1'b0}};
        end
        else begin
            exp_final = exp_s4[FPexp - 1 : 0];
            frac_final = frac_s4[(FPfrac << 1) - 1 : FPfrac];
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            valid_s5 <= 1'b0;

            out_s5 <= {(FP){1'b0}};
        end
        else begin
            valid_s5 <= valid_s4;

            out_s5 <= {sign_s4, exp_final, frac_final};
        end
    end

    assign valid_out = valid_s5;
    assign F_out = out_s5;
endmodule
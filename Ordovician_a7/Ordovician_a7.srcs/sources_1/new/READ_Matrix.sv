`timescale 1ns / 1ps
module READ_Matrix (
    input logic clk,
    input logic rstn,
    input logic readstart,
    output logic readdone,

    output logic [31:0] Matrix_A[0:3][0:7][0:22],
    output logic [31:0] Matrix_B[0:3][0:22][0:7],
    output logic [31:0] Matrix_C[0:3][0:7][0:7],

    output logic [1:0] MUL_valid,
    output logic [1:0] ADD_valid,
    output logic [1:0] Matrix_type
);

    // AXI-Full interface signals for BRAM A (configuration) and BRAM B (matrix data)
    // Clock and reset
    logic s_aclk;
    logic s_aresetn;

    // Busy signals
    logic rsta_busy_A, rsta_busy_B;
    logic rstb_busy_A, rstb_busy_B;

    // Write Address Channel (AW) - Unused
    logic [3:0]  s_axi_awid_A, s_axi_awid_B;
    logic [31:0] s_axi_awaddr_A, s_axi_awaddr_B;
    logic [7:0]  s_axi_awlen_A, s_axi_awlen_B;
    logic [2:0]  s_axi_awsize_A, s_axi_awsize_B;
    logic [1:0]  s_axi_awburst_A, s_axi_awburst_B;
    logic        s_axi_awvalid_A, s_axi_awvalid_B;
    logic        s_axi_awready_A, s_axi_awready_B;

    // Write Data Channel (W) - Unused
    logic [31:0] s_axi_wdata_A, s_axi_wdata_B;
    logic [3:0]  s_axi_wstrb_A, s_axi_wstrb_B;
    logic        s_axi_wlast_A, s_axi_wlast_B;
    logic        s_axi_wvalid_A, s_axi_wvalid_B;
    logic        s_axi_wready_A, s_axi_wready_B;

    // Write Response Channel (B) - Unused
    logic [3:0]  s_axi_bid_A, s_axi_bid_B;
    logic [1:0]  s_axi_bresp_A, s_axi_bresp_B;
    logic        s_axi_bvalid_A, s_axi_bvalid_B;
    logic        s_axi_bready_A, s_axi_bready_B;

    // Read Address Channel (AR)
    logic [3:0]  s_axi_arid_A, s_axi_arid_B;
    logic [31:0] s_axi_araddr_A, s_axi_araddr_B;
    logic [31:0] s_axi_araddr_A_next, s_axi_araddr_B_next;
    logic [7:0]  s_axi_arlen_A, s_axi_arlen_B;
    logic [2:0]  s_axi_arsize_A, s_axi_arsize_B;
    logic [2:0]  s_axi_arsize_A_next, s_axi_arsize_B_next;
    logic [1:0]  s_axi_arburst_A, s_axi_arburst_B;
    logic        s_axi_arvalid_A, s_axi_arvalid_B;
    logic        s_axi_arready_A, s_axi_arready_B;

    // Read Data Channel (R)
    logic [3:0]  s_axi_rid_A, s_axi_rid_B;
    logic [31:0] s_axi_rdata_A, s_axi_rdata_B;
    logic [31:0] s_axi_rdata_B_swapped; // Byte-swapped data for little-endian storage
    logic [1:0]  s_axi_rresp_A, s_axi_rresp_B;
    logic        s_axi_rlast_A, s_axi_rlast_B;
    logic        s_axi_rvalid_A, s_axi_rvalid_B;
    logic        s_axi_rready_A, s_axi_rready_B;

    // Handshake flags
    logic ar_handshake_done_A, ar_handshake_done_A_next;
    logic ar_handshake_done_B, ar_handshake_done_B_next;
    logic r_transaction_done_A, r_transaction_done_B;

    // Connect AXI clock and reset
    assign s_aclk = clk;
    assign s_aresetn = rstn;

    // Byte-swap s_axi_rdata_B for little-endian storage
    assign s_axi_rdata_B_swapped = {s_axi_rdata_B[7:0], s_axi_rdata_B[15:8], s_axi_rdata_B[23:16], s_axi_rdata_B[31:24]};

    // Default values for unused AXI signals
    // Write Address Channel
    assign s_axi_awid_A = 4'h0;
    assign s_axi_awid_B = 4'h0;
    assign s_axi_awaddr_A = 32'h0;
    assign s_axi_awaddr_B = 32'h0;
    assign s_axi_awlen_A = 8'h00;
    assign s_axi_awlen_B = 8'h00;
    assign s_axi_awsize_A = 3'b010;
    assign s_axi_awsize_B = 3'b010;
    assign s_axi_awburst_A = 2'b01;
    assign s_axi_awburst_B = 2'b01;
    assign s_axi_awvalid_A = 1'b0;
    assign s_axi_awvalid_B = 1'b0;

    // Write Data Channel
    assign s_axi_wdata_A = 32'h0;
    assign s_axi_wdata_B = 32'h0;
    assign s_axi_wstrb_A = 4'h0;
    assign s_axi_wstrb_B = 4'h0;
    assign s_axi_wlast_A = 1'b1;
    assign s_axi_wlast_B = 1'b1;
    assign s_axi_wvalid_A = 1'b0;
    assign s_axi_wvalid_B = 1'b0;

    // Write Response Channel
    assign s_axi_bready_A = 1'b0;
    assign s_axi_bready_B = 1'b0;

    // Read Address Channel
    assign s_axi_arid_A = 4'h0;
    assign s_axi_arid_B = 4'h0;
    assign s_axi_arlen_A = 8'h00;      // Single transfer
    assign s_axi_arlen_B = 8'h00;
    assign s_axi_arburst_A = 2'b01;    // INCR burst
    assign s_axi_arburst_B = 2'b01;

    // Instantiate BRAM A (configuration)
    blk_mem_gen_0 u_bram_A (
        .rsta_busy     (rsta_busy_A),
        .rstb_busy     (rstb_busy_A),
        .s_aclk        (s_aclk),
        .s_aresetn     (s_aresetn),
        .s_axi_awid    (s_axi_awid_A),
        .s_axi_awaddr  (s_axi_awaddr_A),
        .s_axi_awlen   (s_axi_awlen_A),
        .s_axi_awsize  (s_axi_awsize_A),
        .s_axi_awburst (s_axi_awburst_A),
        .s_axi_awvalid (s_axi_awvalid_A),
        .s_axi_awready (s_axi_awready_A),
        .s_axi_wdata   (s_axi_wdata_A),
        .s_axi_wstrb   (s_axi_wstrb_A),
        .s_axi_wlast   (s_axi_wlast_A),
        .s_axi_wvalid  (s_axi_wvalid_A),
        .s_axi_wready  (s_axi_wready_A),
        .s_axi_bid     (s_axi_bid_A),
        .s_axi_bresp   (s_axi_bresp_A),
        .s_axi_bvalid  (s_axi_bvalid_A),
        .s_axi_bready  (s_axi_bready_A),
        .s_axi_arid    (s_axi_arid_A),
        .s_axi_araddr  (s_axi_araddr_A),
        .s_axi_arlen   (s_axi_arlen_A),
        .s_axi_arsize  (s_axi_arsize_A),
        .s_axi_arburst (s_axi_arburst_A),
        .s_axi_arvalid (s_axi_arvalid_A),
        .s_axi_arready (s_axi_arready_A),
        .s_axi_rid     (s_axi_rid_A),
        .s_axi_rdata   (s_axi_rdata_A),
        .s_axi_rresp   (s_axi_rresp_A),
        .s_axi_rlast   (s_axi_rlast_A),
        .s_axi_rvalid  (s_axi_rvalid_A),
        .s_axi_rready  (s_axi_rready_A)
    );

    // Instantiate BRAM B (matrix data)
    blk_mem_gen_1 u_bram_B (
        .rsta_busy     (rsta_busy_B),
        .rstb_busy     (rstb_busy_B),
        .s_aclk        (s_aclk),
        .s_aresetn     (s_aresetn),
        .s_axi_awid    (s_axi_awid_B),
        .s_axi_awaddr  (s_axi_awaddr_B),
        .s_axi_awlen   (s_axi_awlen_B),
        .s_axi_awsize  (s_axi_awsize_B),
        .s_axi_awburst (s_axi_awburst_B),
        .s_axi_awvalid (s_axi_awvalid_B),
        .s_axi_awready (s_axi_awready_B),
        .s_axi_wdata   (s_axi_wdata_B),
        .s_axi_wstrb   (s_axi_wstrb_B),
        .s_axi_wlast   (s_axi_wlast_B),
        .s_axi_wvalid  (s_axi_wvalid_B),
        .s_axi_wready  (s_axi_wready_B),
        .s_axi_bid     (s_axi_bid_B),
        .s_axi_bresp   (s_axi_bresp_B),
        .s_axi_bvalid  (s_axi_bvalid_B),
        .s_axi_bready  (s_axi_bready_B),
        .s_axi_arid    (s_axi_arid_B),
        .s_axi_araddr  (s_axi_araddr_B),
        .s_axi_arlen   (s_axi_arlen_B),
        .s_axi_arsize  (s_axi_arsize_B),
        .s_axi_arburst (s_axi_arburst_B),
        .s_axi_arvalid (s_axi_arvalid_B),
        .s_axi_arready (s_axi_arready_B),
        .s_axi_rid     (s_axi_rid_B),
        .s_axi_rdata   (s_axi_rdata_B),
        .s_axi_rresp   (s_axi_rresp_B),
        .s_axi_rlast   (s_axi_rlast_B),
        .s_axi_rvalid  (s_axi_rvalid_B),
        .s_axi_rready  (s_axi_rready_B)
    );

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        READ_CONFIG,
        READ_MATRICES,
        WAIT_DATA,
        FILL_BUBBLES,
        DONE
    } state_t;

    // Matrix shape types
    typedef enum logic [1:0] {
        SHAPE_M8K16N32  = 2'b00,
        SHAPE_M16K16N16 = 2'b01,
        SHAPE_M32K16N8  = 2'b10
    } shape_t;

    // Data types for unpacking
    typedef enum logic [1:0] {
        TYPE_INT4 = 2'b00,
        TYPE_INT8 = 2'b01,
        TYPE_FP16 = 2'b10,
        TYPE_FP32 = 2'b11
    } dtype_t;

    // Internal signals
    logic [7:0] config_reg;
    shape_t shape; // matrix type
    dtype_t dtype_ab, dtype_c; // data type
    logic [31:0] ar_counter, ar_counter_next;
    logic [31:0] elem_counter;
    state_t state, next_state;
    logic config_valid;
    logic [31:0] max_elem_a, max_elem_b, max_elem_c;
    logic [31:0] total_elem_a, total_elem_b;
    logic [3:0] unpack_count;
    logic [31:0] bubble_counter_a, bubble_counter_b; // Separate counters for A and B
    logic [31:0] row_idx, col_idx;
    logic axi_error;
    logic data_ready;
    logic wait_data_done;

    logic [31:0] row, col; // For calculating matrix indices

    // Temporary buffers for bubble filling
    logic [31:0] temp_A[0:3][0:7][0:22];
    logic [31:0] temp_B[0:3][0:22][0:7];
    logic fill_bubbles_init; // Flag to initialize bubble filling

    // Matrix dimensions based on shape
    logic [31:0] rows_a, cols_a, rows_b, cols_b, rows_c, cols_c;

    // Calculate valid and total element counts and dimensions based on shape
    always_comb begin
        case (shape)
            SHAPE_M8K16N32: begin
                max_elem_a = 8 * 16;
                total_elem_a = 8 * 23;
                max_elem_b = 16 * 32;
                total_elem_b = 23 * 32;
                max_elem_c = 8 * 32; // M×N
                rows_a = 8;
                cols_a = 16;
                rows_b = 16;
                cols_b = 32;
                rows_c = 8;
                cols_c = 32;
            end
            SHAPE_M16K16N16: begin
                max_elem_a = 16 * 16;
                total_elem_a = 16 * 23;
                max_elem_b = 16 * 16;
                total_elem_b = 23 * 16;
                max_elem_c = 16 * 16; // M×N
                rows_a = 16;
                cols_a = 16;
                rows_b = 16;
                cols_b = 16;
                rows_c = 16;
                cols_c = 16;
            end
            SHAPE_M32K16N8: begin
                max_elem_a = 32 * 16;
                total_elem_a = 32 * 23;
                max_elem_b = 16 * 8;
                total_elem_b = 23 * 8;
                max_elem_c = 32 * 8; // M×N
                rows_a = 32;
                cols_a = 16;
                rows_b = 16;
                cols_b = 8;
                rows_c = 32;
                cols_c = 8;
            end
            default: begin
                max_elem_a = 0;
                total_elem_a = 0;
                max_elem_b = 0;
                total_elem_b = 0;
                max_elem_c = 0;
                rows_a = 0;
                cols_a = 0;
                rows_b = 0;
                cols_b = 0;
                rows_c = 0;
                cols_c = 0;
            end
        endcase
    end

    // Determine unpack count based on A/B data type
    always_comb begin
        case (dtype_ab)
            TYPE_INT4: unpack_count = 8;
            TYPE_INT8: unpack_count = 4;
            TYPE_FP16: unpack_count = 2;
            TYPE_FP32: unpack_count = 1;
            default: unpack_count = 1;
        endcase
    end

    // Pre-compute address and handshake signals for AXI-A (configuration)
    always_comb begin
        if (state == READ_CONFIG && s_axi_arready_A && s_axi_arvalid_A) begin
            s_axi_araddr_A_next = {20'h0, 10'h0, 2'h0};
            ar_handshake_done_A_next = 1;
            s_axi_arsize_A_next = 3'b010;
        end else begin
            s_axi_araddr_A_next = s_axi_araddr_A;
            ar_handshake_done_A_next = ar_handshake_done_A;
            s_axi_arsize_A_next = s_axi_arsize_A;
        end
    end

    // Pre-compute address, counter, and handshake signals for AXI-B (matrix data)
    always_comb begin
        if (state == READ_MATRICES && s_axi_arready_B && s_axi_arvalid_B) begin
            s_axi_araddr_B_next = {20'h0, ar_counter[9:0], 2'h0};
            ar_counter_next = ar_counter + 1;
            ar_handshake_done_B_next = 1;
            s_axi_arsize_B_next = 3'b010;
        end else begin
            s_axi_araddr_B_next = s_axi_araddr_B;
            ar_counter_next = ar_counter;
            ar_handshake_done_B_next = ar_handshake_done_B;
            s_axi_arsize_B_next = s_axi_arsize_B;
        end
    end

    // State machine: Update current state
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // State machine: Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (readstart && !rsta_busy_A && !rstb_busy_A && !rsta_busy_B && !rstb_busy_B)
                next_state = READ_CONFIG;
            READ_CONFIG: if ((ar_handshake_done_A && r_transaction_done_A) || axi_error)
                next_state = axi_error ? DONE : READ_MATRICES;
            READ_MATRICES: if (ar_handshake_done_B)
                next_state = WAIT_DATA;
            WAIT_DATA: if (data_ready)
                next_state = (elem_counter >= max_elem_a + max_elem_b + max_elem_c && r_transaction_done_B) || axi_error ? FILL_BUBBLES : READ_MATRICES;
            FILL_BUBBLES: if (bubble_counter_a >= total_elem_a && bubble_counter_b >= total_elem_b)
                next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end

    // Main control and data processing
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ar_counter <= 0;
            elem_counter <= 0;
            bubble_counter_a <= 0;
            bubble_counter_b <= 0;
            row_idx <= 0;
            col_idx <= 0;
            s_axi_arvalid_A <= 0;
            s_axi_arvalid_B <= 0;
            s_axi_araddr_A <= 0;
            s_axi_araddr_B <= 0;
            s_axi_arsize_A <= 0;
            s_axi_arsize_B <= 0;
            s_axi_rready_A <= 1;
            s_axi_rready_B <= 1;
            readdone <= 0;
            config_valid <= 0;
            axi_error <= 0;
            Matrix_type <= 0;
            MUL_valid <= 0;
            ADD_valid <= 0;
            Matrix_A <= '{default: 0};
            Matrix_B <= '{default: 0};
            Matrix_C <= '{default: 0};
            temp_A <= '{default: 0};
            temp_B <= '{default: 0};
            ar_handshake_done_A <= 0;
            ar_handshake_done_B <= 0;
            r_transaction_done_A <= 0;
            r_transaction_done_B <= 0;
            data_ready <= 0;
            wait_data_done <= 0;
            fill_bubbles_init <= 0;
        end else begin
            // Update pre-computed values
            s_axi_araddr_A <= s_axi_araddr_A_next;
            s_axi_araddr_B <= s_axi_araddr_B_next;
            s_axi_arsize_A <= s_axi_arsize_A_next;
            s_axi_arsize_B <= s_axi_arsize_B_next;
            ar_counter <= ar_counter_next;
            ar_handshake_done_A <= ar_handshake_done_A_next;
            ar_handshake_done_B <= ar_handshake_done_B_next;

            case (state)
                READ_CONFIG: begin
                    s_axi_arvalid_A <= 1;
                    if (s_axi_rvalid_A && s_axi_rready_A) begin
                        if (s_axi_rresp_A != 2'b00 || !s_axi_rlast_A) begin
                            axi_error <= 1;
                            r_transaction_done_A <= 1;
                        end else begin
                            config_reg <= s_axi_rdata_A[7:0];
                            if (s_axi_rdata_A[7:6] == 2'b00 && s_axi_rdata_A[1:0] != 2'b11) begin
                                Matrix_type <= s_axi_rdata_A[1:0];
                                MUL_valid <= s_axi_rdata_A[3:2];
                                ADD_valid <= s_axi_rdata_A[5:4];
                                shape <= shape_t'(s_axi_rdata_A[1:0]);
                                dtype_ab <= dtype_t'(s_axi_rdata_A[3:2]);
                                dtype_c <= dtype_t'(s_axi_rdata_A[5:4]);
                                config_valid <= 1;
                                r_transaction_done_A <= 1;
                            end else begin
                                r_transaction_done_A <= 1; // Invalid config, still mark as done
                            end
                        end
                    end
                    if (next_state != READ_CONFIG) begin
                        s_axi_arvalid_A <= 0;
                        ar_handshake_done_A <= 0;
                        r_transaction_done_A <= 0;
                    end
                end
                READ_MATRICES: begin
                    s_axi_arvalid_B <= 1;
                    wait_data_done <= 0;
                end
                WAIT_DATA: begin
                    if (s_axi_rvalid_B && s_axi_rready_B && !wait_data_done) begin
                        data_ready <= 1;
                        wait_data_done <= 1;
                        if (s_axi_rresp_B != 2'b00 || !s_axi_rlast_B) begin
                            axi_error <= 1;
                            r_transaction_done_B <= 1;
                        end else if (elem_counter < max_elem_a) begin
                            case (dtype_ab)
                                TYPE_INT4: begin
                                    for (int i = 0; i < 8; i++) begin
                                        if (elem_counter + i < max_elem_a) begin
                                            row = (elem_counter + i) / cols_a;
                                            col = (elem_counter + i) % cols_a;
                                            if (row < rows_a && col < cols_a) begin
                                                Matrix_A[row / 8][row % 8][col] <= {{28{1'b0}}, s_axi_rdata_B[(7-i)*4 +: 4]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 8;
                                end
                                TYPE_INT8: begin
                                    for (int i = 0; i < 4; i++) begin
                                        if (elem_counter + i < max_elem_a) begin
                                            row = (elem_counter + i) / cols_a;
                                            col = (elem_counter + i) % cols_a;
                                            if (row < rows_a && col < cols_a) begin
                                                Matrix_A[row / 8][row % 8][col] <= {{24{1'b0}}, s_axi_rdata_B[(3-i)*8 +: 8]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 4;
                                end
                                TYPE_FP16: begin
                                    for (int i = 0; i < 2; i++) begin
                                        if (elem_counter + i < max_elem_a) begin
                                            row = (elem_counter + i) / cols_a;
                                            col = (elem_counter + i) % cols_a;
                                            if (row < rows_a && col < cols_a) begin
                                                Matrix_A[row / 8][row % 8][col] <= {{16{1'b0}}, s_axi_rdata_B[(1-i)*16 +: 16]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 2;
                                end
                                TYPE_FP32: begin
                                    row = elem_counter / cols_a;
                                    col = elem_counter % cols_a;
                                    if (row < rows_a && col < cols_a) begin
                                        Matrix_A[row / 8][row % 8][col] <= s_axi_rdata_B_swapped;
                                    end
                                    elem_counter <= elem_counter + 1;
                                end
                            endcase
                        end else if (elem_counter < max_elem_a + max_elem_b) begin
                            case (dtype_ab)
                                TYPE_INT4: begin
                                    for (int i = 0; i < 8; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b) begin
                                            row = (elem_counter + i - max_elem_a) / cols_b;
                                            col = (elem_counter + i - max_elem_a) % cols_b;
                                            if (row < rows_b && col < cols_b) begin
                                                Matrix_B[col / 8][row][col % 8] <= {{28{1'b0}}, s_axi_rdata_B[(7-i)*4 +: 4]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 8;
                                end
                                TYPE_INT8: begin
                                    for (int i = 0; i < 4; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b) begin
                                            row = (elem_counter + i - max_elem_a) / cols_b;
                                            col = (elem_counter + i - max_elem_a) % cols_b;
                                            if (row < rows_b && col < cols_b) begin
                                                Matrix_B[col / 8][row][col % 8] <= {{24{1'b0}}, s_axi_rdata_B[(3-i)*8 +: 8]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 4;
                                end
                                TYPE_FP16: begin
                                    for (int i = 0; i < 2; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b) begin
                                            row = (elem_counter + i - max_elem_a) / cols_b;
                                            col = (elem_counter + i - max_elem_a) % cols_b;
                                            if (row < rows_b && col < cols_b) begin
                                                Matrix_B[col / 8][row][col % 8] <= {{16{1'b0}}, s_axi_rdata_B[(1-i)*16 +: 16]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 2;
                                end
                                TYPE_FP32: begin
                                    row = (elem_counter - max_elem_a) / cols_b;
                                    col = (elem_counter - max_elem_a) % cols_b;
                                    if (row < rows_b && col < cols_b) begin
                                        Matrix_B[col / 8][row][col % 8] <= s_axi_rdata_B_swapped;
                                    end
                                    elem_counter <= elem_counter + 1;
                                end
                            endcase
                        end else begin
                            case (dtype_c)
                                TYPE_INT4: begin
                                    for (int i = 0; i < 8; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b + max_elem_c) begin
                                            row = (elem_counter + i - max_elem_a - max_elem_b) / cols_c;
                                            col = (elem_counter + i - max_elem_a - max_elem_b) % cols_c;
                                            if (row < rows_c && col < cols_c) begin
                                                Matrix_C[(row / 8) * (cols_c / 8) + (col / 8)][row % 8][col % 8] <= {{28{1'b0}}, s_axi_rdata_B[(7-i)*4 +: 4]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 8;
                                end
                                TYPE_INT8: begin
                                    for (int i = 0; i < 4; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b + max_elem_c) begin
                                            row = (elem_counter + i - max_elem_a - max_elem_b) / cols_c;
                                            col = (elem_counter + i - max_elem_a - max_elem_b) % cols_c;
                                            if (row < rows_c && col < cols_c) begin
                                                Matrix_C[(row / 8) * (cols_c / 8) + (col / 8)][row % 8][col % 8] <= {{24{1'b0}}, s_axi_rdata_B[(3-i)*8 +: 8]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 4;
                                end
                                TYPE_FP16: begin
                                    for (int i = 0; i < 2; i++) begin
                                        if (elem_counter + i < max_elem_a + max_elem_b + max_elem_c) begin
                                            row = (elem_counter + i - max_elem_a - max_elem_b) / cols_c;
                                            col = (elem_counter + i - max_elem_a - max_elem_b) % cols_c;
                                            if (row < rows_c && col < cols_c) begin
                                                Matrix_C[(row / 8) * (cols_c / 8) + (col / 8)][row % 8][col % 8] <= {{16{1'b0}}, s_axi_rdata_B[(1-i)*16 +: 16]};
                                            end
                                        end
                                    end
                                    elem_counter <= elem_counter + 2;
                                end
                                TYPE_FP32: begin
                                    row = (elem_counter - max_elem_a - max_elem_b) / cols_c;
                                    col = (elem_counter - max_elem_a - max_elem_b) % cols_c;
                                    if (row < rows_c && col < cols_c) begin
                                        Matrix_C[(row / 8) * (cols_c / 8) + (col / 8)][row % 8][col % 8] <= s_axi_rdata_B_swapped;
                                    end
                                    elem_counter <= elem_counter + 1;
                                end
                            endcase
                        end
                        r_transaction_done_B <= 1;
                    end else begin
                        if (wait_data_done) begin
                            data_ready <= 1;
                        end else begin
                            data_ready <= 0;
                        end
                    end
                    if (next_state != WAIT_DATA && next_state != READ_MATRICES) begin
                        s_axi_arvalid_B <= 0;
                        ar_handshake_done_B <= 0;
                        r_transaction_done_B <= 0;
                    end
                end
                FILL_BUBBLES: begin
                    if (!fill_bubbles_init) begin
                        // Step 1: Copy data to temporary buffers and clear original matrices
                        temp_A <= Matrix_A;
                        temp_B <= Matrix_B;
                        Matrix_A <= '{default: 0};
                        Matrix_B <= '{default: 0};
                        fill_bubbles_init <= 1;
                        bubble_counter_a <= 0;
                        bubble_counter_b <= 0;
                    end else begin
                        // Process Matrix_A
                        if (bubble_counter_a < total_elem_a) begin
                            logic [31:0] block_idx_a, local_row, src_col;
                            block_idx_a = (bubble_counter_a / 23) / 8; // Block index (every 8 rows)
                            local_row = (bubble_counter_a / 23) % 8; // Row within the block (0-7)
                            col = bubble_counter_a % 23; // Destination column (0-22)
                            // Calculate source column: shift left by local_row positions
                            src_col = (col >= local_row) ? col - local_row : 0;
                            // Explicitly clear bubble region
                            if (col < local_row || src_col >= cols_a) begin
                                Matrix_A[block_idx_a][local_row][col] <= 0;
                            end
                            // Copy data if within valid range
                            else if (col >= local_row && src_col < cols_a) begin
                                Matrix_A[block_idx_a][local_row][col] <= temp_A[block_idx_a][local_row][src_col];
                            end
                            bubble_counter_a <= bubble_counter_a + 1;
                        end
                        // Process Matrix_B
                        else if (bubble_counter_b < total_elem_b) begin
                            logic [31:0] block_idx_b, local_col, local_row, src_row;
                            block_idx_b = bubble_counter_b / (23 * 8); // Block index (every 8 columns)
                            local_col = (bubble_counter_b / 23) % 8; // Column within the block
                            local_row = bubble_counter_b % 23; // Row within the block
                            row = local_row;
                            // Calculate source row: shift up by local_col positions
                            src_row = row - local_col;
                            // Explicitly clear bubble region (rows before local_col)
                            if (row < local_col || row >= rows_b + local_col || src_row >= rows_b) begin
                                Matrix_B[block_idx_b][row][local_col] <= 0;
                            end
                            // Copy data if within valid range
                            else if (local_col < cols_b && row >= local_col && row < rows_b + local_col && src_row < rows_b) begin
                                Matrix_B[block_idx_b][row][local_col] <= temp_B[block_idx_b][src_row][local_col];
                            end
                            bubble_counter_b <= bubble_counter_b + 1;
                        end else begin
                            // Done with bubble filling
                            fill_bubbles_init <= 0;
                        end
                    end
                end
                DONE: begin
                    s_axi_arvalid_A <= 0;
                    s_axi_arvalid_B <= 0;
                    readdone <= 1;
                    ar_counter <= 0;
                    elem_counter <= 0;
                    bubble_counter_a <= 0;
                    bubble_counter_b <= 0;
                    config_valid <= 0;
                    axi_error <= 0;
                    fill_bubbles_init <= 0;
                end
                default: begin
                    s_axi_arvalid_A <= 0;
                    s_axi_arvalid_B <= 0;
                    readdone <= 0;
                end
            endcase
        end
    end

endmodule
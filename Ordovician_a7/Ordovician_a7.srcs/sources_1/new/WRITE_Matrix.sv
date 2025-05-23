`timescale 1ns / 1ps

module WRITE_Matrix (
    input logic clk,
    input logic rstn,
    input logic writestart,
    output logic writedone,

    input logic [31:0] Matrix_C[0:3][0:7][0:7],

    input logic [1:0] MUL_valid,
    input logic [1:0] ADD_valid,
    input logic [1:0] Matrix_type
);

    // AXI-Full interface signals for BRAM
    logic s_aclk;
    logic s_aresetn;

    // Write Address Channel (AW)
    logic [3:0]  s_axi_awid;
    logic [31:0] s_axi_awaddr;
    logic [7:0]  s_axi_awlen;
    logic [2:0]  s_axi_awsize;
    logic [1:0]  s_axi_awburst;
    logic        s_axi_awvalid;
    logic        s_axi_awready;

    // Write Data Channel (W)
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wlast;
    logic        s_axi_wvalid;
    logic        s_axi_wready;

    // Write Response Channel (B)
    logic [3:0]  s_axi_bid;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;

    // Internal signals
    typedef enum logic [2:0] {
        IDLE,
        WRITE_ADDR,
        WRITE_DATA,
        WAIT_RESP,
        DONE
    } state_t;
    
    state_t state, next_state;
    logic [31:0] write_counter;
    logic [31:0] max_elem_c;
    logic [31:0] rows_c, cols_c;
    logic [2:0] pack_count;
    logic [31:0] data_buffer;
    logic [3:0] data_ptr;

    // Matrix dimensions and data packing
    always_comb begin
        case (Matrix_type)
            2'b00: begin // SHAPE_M8K16N32
                rows_c = 8;
                cols_c = 32;
                max_elem_c = 8 * 32;
            end
            2'b01: begin // SHAPE_M16K16N16
                rows_c = 16;
                cols_c = 16;
                max_elem_c = 16 * 16;
            end
            2'b10: begin // SHAPE_M32K16N8
                rows_c = 32;
                cols_c = 8;
                max_elem_c = 32 * 8;
            end
            default: begin
                rows_c = 0;
                cols_c = 0;
                max_elem_c = 0;
            end
        endcase

        // Determine packing based on ADD_valid (assuming it encodes dtype_c)
        case (ADD_valid)
            2'b00: pack_count = 8; // INT4
            2'b01: pack_count = 4; // INT8
            2'b10: pack_count = 2; // FP16
            2'b11: pack_count = 1; // FP32
        endcase
        
    end

    // AXI clock and reset
    assign s_aclk = clk;
    assign s_aresetn = rstn;

    // Default values for unused signals
    assign s_axi_awid = 4'h0;
    assign s_axi_awburst = 2'b01; // INCR
    assign s_axi_wstrb = 4'hF;
    assign s_axi_bready = 1'b1;

    // BRAM instantiation (same as READ module's BRAM B)
    blk_mem_gen_1 u_bram (
        .s_aclk        (s_aclk),
        .s_aresetn     (s_aresetn),
        .s_axi_awid    (s_axi_awid),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awlen   (s_axi_awlen),
        .s_axi_awsize  (3'b010), // 4 bytes
        .s_axi_awburst (s_axi_awburst),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bid     (s_axi_bid),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready)
    );

    logic [31:0] pack_step;
    always_comb begin
        case (ADD_valid)
            2'b00: pack_step = 8;
            2'b01: pack_step = 4;
            2'b10: pack_step = 2;
            2'b11: pack_step = 1;
        endcase
    end

    function automatic logic [31:0] pack_data(
        input logic [1:0] add_valid,
        input int idx_base,
        input int element_offset,
        input int bit_width
    );
        int global_idx = idx_base + element_offset;
        int row_in_matrix, col_in_matrix;
        int block_idx, block_row, block_col;
        logic [31:0] pack_ed;
    begin
        // 计算全局索引
        row_in_matrix = global_idx / cols_c;
        col_in_matrix = global_idx % cols_c;

        // 块索引计算
        case (Matrix_type)
            2'b00: begin // SHAPE_M8K16N32
                block_idx = col_in_matrix / 8;
                block_row = row_in_matrix;
                block_col = col_in_matrix % 8;
            end
            2'b01: begin // SHAPE_M16K16N16
                block_idx = (row_in_matrix / 8) * 2 + (col_in_matrix / 8);
                block_row = row_in_matrix % 8;
                block_col = col_in_matrix % 8;
            end
            2'b10: begin // SHAPE_M32K16N8
                block_idx = row_in_matrix / 8;
                block_row = row_in_matrix % 8;
                block_col = col_in_matrix;
            end
        endcase

        // 数据提取和打包
        case (bit_width)
            4:  pack_ed[31-element_offset*4 -:4] = Matrix_C[block_idx][block_row][block_col][3:0];
            8:  pack_ed[31-element_offset*8 -:8] = Matrix_C[block_idx][block_row][block_col][7:0];
            16: pack_ed[31-element_offset*16 -:16] = Matrix_C[block_idx][block_row][block_col][15:0];
            32: pack_ed = Matrix_C[block_idx][block_row][block_col];
        endcase

        return pack_ed;
    end
    endfunction

    logic preload;
    // State machine
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            write_counter <= 0;
            data_buffer <= 0;
            data_ptr <= 0;
            preload <= 0;
        end else begin
            
            state <= next_state;
            
            case (state)
                WRITE_ADDR: begin
                    if (s_axi_awready) begin
                        write_counter <= 0;
                        data_ptr <= 0;
                        preload <= 1;
                        data_buffer <= pack_data(ADD_valid, 0, 0, 32); // FP32特殊处理
                    end
                end
                
                WRITE_DATA: begin
                    
                    if (s_axi_wready) begin

                        if (preload) begin
                            // 预加载第一个数据
                            preload <= 0;
                            write_counter <= write_counter + pack_step;
                        end
                        // 数据打包主逻辑;
                        case (ADD_valid)
                            2'b00: begin // INT4
                                data_buffer = 0;
                                for (int i=0; i<8; i++) begin
                                    if (write_counter+i < max_elem_c) begin
                                        data_buffer |= pack_data(ADD_valid, write_counter+4, i, 4);
                                    end
                                end
                                write_counter <= write_counter + 8;
                            end
                            2'b01: begin // INT8
                                data_buffer = 0;
                                for (int i=0; i<4; i++) begin
                                    if (write_counter+i < max_elem_c) begin
                                        data_buffer |= pack_data(ADD_valid, write_counter+8, i, 8);
                                    end
                                end
                                write_counter <= write_counter + 4;
                            end
                            2'b10: begin // FP16
                                data_buffer = 0;
                                for (int i=0; i<2; i++) begin
                                    if (write_counter+i < max_elem_c) begin
                                        data_buffer |= pack_data(ADD_valid, write_counter+16, i, 16);
                                    end
                                end
                                write_counter <= write_counter + 2;
                            end
                            2'b11: begin // FP32
                                if (write_counter < max_elem_c) begin
                                    data_buffer = pack_data(ADD_valid, write_counter+1, 0, 32);
                                end
                                write_counter <= write_counter + 1;
                            end
                        endcase
                    end
                end
                
                DONE: begin
                    write_counter <= 0;
                    data_buffer <= 0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: 
                if (writestart) 
                    next_state = WRITE_ADDR;
                    
            WRITE_ADDR: 
                if (s_axi_awready) 
                    next_state = WRITE_DATA;
                    
            WRITE_DATA: 
                if (write_counter >= max_elem_c - pack_step && ~s_axi_wready) 
                    next_state = WAIT_RESP;
                    
            WAIT_RESP: 
                if (s_axi_bvalid) 
                    next_state = DONE;
                    
            DONE: 
                next_state = IDLE;
        endcase
    end

    // AXI control signals
    assign s_axi_awvalid = (state == WRITE_ADDR);
    assign s_axi_awaddr = write_counter * 4; // Byte addressing
    assign s_axi_awlen = (max_elem_c/pack_count) - 1; // Burst length
    assign s_axi_wvalid = (state == WRITE_DATA);
    assign s_axi_wdata = data_buffer;
    assign s_axi_wlast = (write_counter == max_elem_c - pack_step);
    assign writedone = (state == DONE);

endmodule

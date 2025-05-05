`timescale 1ns / 1ps
module AXI_slave (
	input  logic                     clk,
	input  logic                     rstn,

	// AXI4 Write Data Channel
	input  logic [31:0]    			 wdata,
	input  logic                     wvalid,
	output logic                     wready,

	// AXI4 Write Response Channel
	output logic [1:0]               bresp,
	output logic                     bvalid,
	input  logic                     bready,

	// User Interface
	output logic [31:0]    			 received_data,
	output logic                     data_valid
);

	// 状态机定义
	typedef enum logic [1:0] {
		IDLE,
		RESP_PENDING
	} state_t;

	state_t current_state, next_state;

	// 状态转移逻辑
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= IDLE;
		end
		else begin
			current_state <= next_state;
		end
	end

	// 下一状态逻辑
	always_comb begin
		next_state = current_state;
		case (current_state)
			IDLE: begin
				if (wvalid) next_state = RESP_PENDING;
			end
			RESP_PENDING:  if (bvalid && bready) next_state = IDLE;
		endcase
	end

	// 输出逻辑
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wready     <= 1'b0;
			bvalid     <= 1'b0;
			bresp      <= 2'b00;
			data_valid <= 1'b0;
			received_data <= 0;
		end
		else begin
			case (current_state)
				IDLE: begin
					wready  <= 1'b1;
					if (wvalid && wready) begin
						received_data <= wdata;
						data_valid <= 1;
						wready  <= 1'b0;
						bvalid  <= 1'b1;
					end
					else data_valid <= 0;
				end
				
				RESP_PENDING: begin
					data_valid <= 0;
					if (bvalid && bready) begin
						bvalid <= 1'b0;
						wready <= 1'b1;
					end
				end
			endcase
		end
	end

endmodule
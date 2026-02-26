`timescale 1ns/1ps

// size M*N
`define M 18
`define N 6

// signed / unsigned
`define SIGN

// synchronous / asynchronous reset
`define ASYNC

module mult(
		input clk,
		input rst,
		input [`M-1:0] a,
		input [`N-1:0] b,
		output [`M+`N-1:0] p
	);

	wire clk;
	wire rst;

`ifdef SIGN
	wire signed [`M-1:0] a;
	wire signed [`N-1:0] b;
	wire signed [`M+`N-1:0] p;

	reg signed [`M-1:0] a_i;
	reg signed [`N-1:0] b_i;
	reg signed [`M+`N-1:0] p_i;
`else
	wire [`M-1:0] a;
	wire [`N-1:0] b;
	wire [`M+`N-1:0] p;

	reg [`M-1:0] a_i;
	reg [`N-1:0] b_i;
	reg [`M+`N-1:0] p_i;
`endif

	assign p = p_i;

`ifdef ASYNC
	always @(posedge clk or negedge rst)
`else // SYNC
	always @(posedge clk)
`endif
	begin
		if (!rst) begin
			a_i <= 0;
			b_i <= 0;
			p_i <= 0;
		end
		else begin
			a_i <= a;
			b_i <= b;
			p_i <= a_i * b_i;
		end
	end

endmodule

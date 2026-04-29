`timescale 1 ns / 1 ps

module tb;

	parameter M = 18;
    parameter N = 6;

	reg clk;
	reg rst;
	
    reg signed [M-1:0] a, ref_a;
	reg signed [N-1:0] b, ref_b;
    reg signed [N+M-1:0] ref_p;
	wire signed [N+M-1:0] p;

	initial begin
`ifdef CCSDF
		$sdf_annotate("mult_00.sdf", dut);
`endif
		$dumpfile("sim/mult_tb.vcd");
		$dumpvars(0, tb);
		clk = 0;
		rst = 0;
	end

	always clk = #1 ~clk;

    always @(posedge clk)
	begin: _ref
		ref_a <= a;
		ref_b <= b;
		ref_p <= ref_a * ref_b;
	end

	mult dut (
		.clk(clk),
		.rst(rst),
		.a(a), .b(b), .p(p)
	);

    integer i;

	initial begin
        i = 0;
		#200;
		rst = 1;
		while (i < 100) begin
			a = $urandom%(2**M);
			b = $urandom%(2**N);
			#2;
    		$display("[STATUS] i=%0d: a:%0d, b:%0d, p:%0d, p_ref:%0d", i, a, b, p, ref_p);
            i = i + 1;
		end
		$finish;
	end

endmodule

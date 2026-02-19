`timescale 1 ns / 1 ps

module tb;

	reg clk;
	reg rst;
	wire led;

	initial begin
`ifdef CCSDF
		$sdf_annotate("blink_00.sdf", dut);
`endif
		$dumpfile("sim/blink_tb.vcd");
		$dumpvars(0, tb);
		clk = 0;
		rst = 0;
	end

	always clk = #100 ~clk;

	blink dut (
		.clk(clk),
		.rst(rst),
		.led(led)
	);

	initial begin
		#200;
		rst = 1;
		#500;
		$finish;
	end

endmodule

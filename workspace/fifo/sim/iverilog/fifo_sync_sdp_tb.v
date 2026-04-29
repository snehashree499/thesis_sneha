`timescale 1 ns / 1 ps

`ifndef TICKS
`define TICKS 5
`endif

module tb;

	reg  PUSHPOP_CLK;
	reg  POP_EN, PUSH_EN, PUSH_WE;
	reg  F_RST_N;
	reg  [79:0] DI;
	reg  [79:0] BM;
	wire [79:0] DO;
	wire F_FULL, F_EMPTY, F_ALMOST_FULL, F_ALMOST_EMPTY;
	wire [15:0] F_RD_PTR;
	wire [15:0] F_WR_PTR;

	reg [19:0] p0 = 0;
	reg [19:0] p1 = 0;
	reg [19:0] p2 = 0;
	reg [19:0] p3 = 0;

	initial begin
`ifdef CCSDF
		$sdf_annotate("fifo_sync_sdp_00.sdf", dut);
`endif
		$dumpfile("sim/fifo_sync_sdp_tb.vcd");
		$dumpvars(0, tb);
		PUSHPOP_CLK = 0;
		POP_EN      = 0;
		PUSH_EN     = 0;
		PUSH_WE     = 0;
		F_RST_N     = 0;
		DI          = 0;
		BM          = {80{1'b1}};
	end

	always PUSHPOP_CLK = #1 ~PUSHPOP_CLK;

	fifo_sync_sdp dut (
		.POP_CLK(PUSHPOP_CLK), // sync clk
		//.PUSH_CLK(PUSH_CLK), // unused
		.POP_EN(POP_EN),
		.PUSH_EN(PUSH_EN),
		.PUSH_WE(PUSH_WE),
		.DI(DI),
		.BM(BM),
		.DO(DO),
		.DYN_ALMOST_FULL_OFFSET(15'h7),  // only if DYN_STAT_SELECT=1
		.DYN_ALMOST_EMPTY_OFFSET(15'h8), // only if DYN_STAT_SELECT=1
		.F_RST_N(F_RST_N),
		.F_FULL(F_FULL),
		.F_EMPTY(F_EMPTY),
		.F_ALMOST_FULL(F_ALMOST_FULL),
		.F_ALMOST_EMPTY(F_ALMOST_EMPTY),
		.F_RD_ERROR(F_RD_ERROR),
		.F_WR_ERROR(F_WR_ERROR),
		.F_RD_PTR(F_RD_PTR),
		.F_WR_PTR(F_WR_PTR)
	);

	integer wr = 0, rd = 0;

	task status_wr;
		$write("[STATUS] clk no. %0d at %0d ns / %0d ns (%.2f %% complete)\015", (wr+1)/2, (wr+1), `TICKS, (100.0/`TICKS) * (wr+1));
	endtask

	task status_rd;
		$write("[STATUS] clk no. %0d at %0d ns / %0d ns (%.2f %% complete)\015", (rd+1)/2, (rd+1), `TICKS, (100.0/`TICKS) * (rd+1));
	endtask

	initial begin
		#200;
		F_RST_N = ~F_RST_N;
		#10;
		$write("Push data\n");
		PUSH_EN = 1;
		#10;
		PUSH_WE = 1;
		for (wr=0; wr<`TICKS; wr=wr+1) begin
			p0 = $urandom%(2**20);
			p1 = $urandom%(2**20);
			p2 = $urandom%(2**20);
			p3 = $urandom%(2**20);
			DI = {p3, p2, p1, p0};
			#2;
			status_wr;
		end
		$write("\nPop data\n");
		POP_EN = 1; PUSH_WE = 0;
		for (rd=0; rd<`TICKS; rd=rd+1) begin
			#2;
			status_rd;
		end
		$write("\nFinished\n");
		$finish;
	end

endmodule

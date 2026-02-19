
module fifo_async_sdp (
  input wire  POP_CLK, PUSH_CLK,
  input wire  POP_EN, PUSH_EN, PUSH_WE,
  input wire  [79:0] DI, BM,
  output wire [79:0] DO,
  input wire  [14:0] DYN_ALMOST_FULL_OFFSET,
  input wire  [14:0] DYN_ALMOST_EMPTY_OFFSET,
  input wire  F_RST_N,
  output wire F_FULL, F_EMPTY, F_ALMOST_FULL, F_ALMOST_EMPTY,
  output wire F_RD_ERROR, F_WR_ERROR,
  output wire [15:0] F_RD_PTR, F_WR_PTR
);

  CC_FIFO_40K #(
    .ALMOST_FULL_OFFSET(15'hf),  // only if DYN_STAT_SELECT=0
    .ALMOST_EMPTY_OFFSET(15'hf), // only if DYN_STAT_SELECT=0
    .DYN_STAT_SELECT(0), // must be 0 in SDP mode
    .A_WIDTH(80), // SDP: fixed 80
    .B_WIDTH(80), // SDP: fixed 80
    .FIFO_MODE("ASYNC"),
    .RAM_MODE("SDP"),
    .A_CLK_INV(0), .B_CLK_INV(0),
    .A_EN_INV(0), .B_EN_INV(0),
    .A_WE_INV(0), .B_WE_INV(0),
    .A_DO_REG(0), .B_DO_REG(0),
    .A_ECC_EN(0), .B_ECC_EN(0)
  ) fifo_inst (
    .A_CLK(POP_CLK),
    .B_CLK(PUSH_CLK),
    .A_EN(POP_EN),
    .B_EN(PUSH_EN),
    .B_WE(PUSH_WE),
    .A_DI(DI[39:0]),
    .B_DI(DI[79:40]),
    .A_BM(BM[39:0]),
    .B_BM(BM[79:40]),
    .A_DO(DO[39:0]),
    .B_DO(DO[79:40]),
    .F_ALMOST_FULL_OFFSET(DYN_ALMOST_FULL_OFFSET),   // only if DYN_STAT_SELECT=1
    .F_ALMOST_EMPTY_OFFSET(DYN_ALMOST_EMPTY_OFFSET), // only if DYN_STAT_SELECT=1
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

endmodule

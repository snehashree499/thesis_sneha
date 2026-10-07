// ============================================================================
//  uart_rx9.v  -  UART receiver for 9-bit Flexlink symbols
// ============================================================================
//
//  One symbol on the wire (11 bits in total):
//
//      idle  start  d0 d1 d2 d3 d4 d5 d6 d7 d8  stop  idle
//      ──1──┐  0  ┌─────── 9 data bits ───────┐  1  ──1──
//           └─────┘     (LSB first, d8 = control bit)
//
//  How it works:
//    - Wait for the line to go low (start bit).
//    - Wait half a bit and check it is still low. This rejects short glitches
//      and moves the sampling point to the MIDDLE of each bit, where the
//      signal is most stable.
//    - Then sample once every full bit time, nine times.
//    - Finally check that the stop bit is high. Only then is 'valid' pulsed.
// ============================================================================

module uart_rx9 #(
    parameter CLKS_PER_BIT = 50          // clock / baud, e.g. 50 MHz / 1 MBaud
)(
    input  wire       clk,
    input  wire       rx,
    output reg  [8:0] data  = 9'd0,
    output reg        valid = 1'b0       // one-clock pulse: 'data' is new
);

    // The rx pin changes at any time, not in step with our clock.
    // Two flip-flops in a row make it safe to use (synchroniser).
    reg rx_meta = 1'b1;
    reg rx_sync = 1'b1;
    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    reg  [1:0] state   = IDLE;
    reg [15:0] clk_cnt = 16'd0;   // 16 bits: enough for slow baud rates too
    reg  [3:0] bit_idx = 4'd0;    // which data bit we are on (0..8)

    always @(posedge clk) begin
        valid <= 1'b0;

        case (state)
            IDLE: begin
                if (rx_sync == 1'b0) begin           // falling edge: start bit
                    state   <= START;
                    clk_cnt <= 16'd0;
                end
            end

            START: begin                              // go to the middle of the start bit
                if (clk_cnt == CLKS_PER_BIT/2 - 1) begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    state   <= (rx_sync == 1'b0) ? DATA : IDLE;   // still low = real start
                end else
                    clk_cnt <= clk_cnt + 16'd1;
            end

            DATA: begin                               // sample the middle of each data bit
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt       <= 16'd0;
                    data[bit_idx] <= rx_sync;
                    if (bit_idx == 4'd8)
                        state <= STOP;                // all 9 bits received
                    bit_idx <= bit_idx + 4'd1;
                end else
                    clk_cnt <= clk_cnt + 16'd1;
            end

            STOP: begin                               // stop bit must be 1
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 16'd0;
                    state   <= IDLE;
                    valid   <= (rx_sync == 1'b1);
                end else
                    clk_cnt <= clk_cnt + 16'd1;
            end
        endcase
    end

endmodule

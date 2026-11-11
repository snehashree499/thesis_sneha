`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_flexlink_node.v  -  simulation only: PC -> GM1 -> GM2  (+ one GM alone)
//
//   chain:  PC Tx -> GM1 pin1,  GM1 pin3 -> GM2 pin1,  GM2 pin2 -> GM1 pin4,  GM1 pin2 -> PC Rx
//           GM2 pin4 = 0 (pulldown, nothing connected -> GM2 is last)
//   solo :  one more GM on the same PC Tx, its pin4 = 0 -> it is last, total must be 1
//
//   Tests:
//     1) LED before count      -> answers with ID FF (not counted yet)            // [NEW]
//     2) count segments        -> PC gets 1B0 000 176 1B0 001 176, GM1 id 0, GM2 id 1  // [NEW]
//     3) LED frame             -> LED pins right, answers 180 000 028 176 180 001 028 176 // [NEW]
//     4) short LED frame       -> GM1 updates + answers, GM2 keeps old + no answer
//     5) other command (170)   -> nothing changes, no answer
//   Prints PASS or FAIL.
// ---------------------------------------------------------------------------
module tb_flexlink_node;
    reg clk = 0; always #10 clk = ~clk;          // 50 MHz (fake PLL below passes it through)
    reg pc_tx = 1;                               // PC -> GM1, idle = 1

    wire up_12, dn_21, pc_rx, up_end, solo_rx, solo_up;
    wire [7:0] led1_n, led2_n, led_s_n;
    wire r1, g1, b1, w1, r2, g2, b2, w2, rs, gs, bs, ws;

    flexlink_node gm1  (.clk(clk), .up_rx(pc_tx), .up_tx(up_12),   .dn_rx(dn_21), .dn_tx(pc_rx),
                        .leds_n(led1_n), .seg1(r1), .seg2(g1), .seg3(b1), .seg4(w1));
    flexlink_node gm2  (.clk(clk), .up_rx(up_12), .up_tx(up_end),  .dn_rx(1'b0),  .dn_tx(dn_21),
                        .leds_n(led2_n), .seg1(r2), .seg2(g2), .seg3(b2), .seg4(w2));
    flexlink_node solo (.clk(clk), .up_rx(pc_tx), .up_tx(solo_up), .dn_rx(1'b0),  .dn_tx(solo_rx),
                        .leds_n(led_s_n), .seg1(rs), .seg2(gs), .seg3(bs), .seg4(ws));

    // localparam BIT = 8680;                    // 1 / 115200 = 8.68 us   (old)
    localparam BIT = 1000;                       // [NEW] 1 / 1 MBaud = 1 us
    integer i, n, k, errors = 0;
    integer c [0:7];

    // ---- PC Tx ----
    task send9(input [8:0] v); begin
        pc_tx = 0; #BIT;
        for (i = 0; i < 9; i = i + 1) begin pc_tx = v[i]; #BIT; end
        pc_tx = 1; #BIT;
    end endtask

    task send16(input [15:0] v); begin send9({1'b0, v[15:8]}); send9({1'b0, v[7:0]}); end endtask

    task frame(input [15:0] r1v, g1v, b1v, w1v, r2v, g2v, b2v, w2v); begin
        send9(9'h100);
        send16(r1v); send16(g1v); send16(b1v); send16(w1v);
        send16(r2v); send16(g2v); send16(b2v); send16(w2v);
        send9(9'h176);
        #1000000;                                // let everything go through + answers come back
    end endtask

    // ---- PC Rx: collect what comes back on GM1 pin2 (and solo pin2) ----
    wire [8:0] pc_word, solo_word;  wire pc_valid, solo_valid;
    // uart_rx9 pc_receiver   (.clk(clk), .rx(pc_rx),   .data(pc_word),   .valid(pc_valid));     (old)
    // uart_rx9 solo_receiver (.clk(clk), .rx(solo_rx), .data(solo_word), .valid(solo_valid)); (old)
    uart_rx9 #(.CLKS_PER_BIT(50)) pc_receiver   (.clk(clk), .rx(pc_rx),   .data(pc_word),   .valid(pc_valid));   // [NEW]
    uart_rx9 #(.CLKS_PER_BIT(50)) solo_receiver (.clk(clk), .rx(solo_rx), .data(solo_word), .valid(solo_valid)); // [NEW]

    reg [8:0] got [0:63];  integer n_got = 0, n_seen = 0;
    reg [8:0] sgot[0:63];  integer s_got = 0;
    always @(posedge clk) begin
        if (pc_valid)   begin got[n_got]  <= pc_word;   n_got <= n_got + 1; end
        if (solo_valid) begin sgot[s_got] <= solo_word; s_got <= s_got + 1; end
    end

    // compare new words with exp[0..count-1]
    reg [8:0] exp [0:15];
    task check_dn(input integer count); begin
        $write("  PC received:");
        for (k = n_seen; k < n_got; k = k + 1) $write(" %h", got[k]);
        if (n_got == n_seen) $write(" (nothing)");
        $display("");
        if (n_got - n_seen != count) begin
            errors = errors + 1; $display("  <-- WRONG number of words (expected %0d)", count);
        end else begin
            for (k = 0; k < count; k = k + 1)
                if (got[n_seen + k] !== exp[k]) begin
                    errors = errors + 1; $display("  <-- WRONG word %0d: %h, expected %h", k, got[n_seen + k], exp[k]);
                end
        end
        n_seen = n_got;
    end endtask

    task set_exp8(input [8:0] a0, a1, a2, a3, a4, a5, a6, a7); begin
        exp[0]=a0; exp[1]=a1; exp[2]=a2; exp[3]=a3; exp[4]=a4; exp[5]=a5; exp[6]=a6; exp[7]=a7;
    end endtask

    // ---- LED pins: count how long each pin is high in one PWM period ----
    function [16:0] e(input [15:0] v); e = (v == 16'hFFFF) ? 17'd65536 : {1'b0, v}; endfunction

    task check(input [15:0] r1v, g1v, b1v, w1v, r2v, g2v, b2v, w2v); begin
        for (n = 0; n < 8; n = n + 1) c[n] = 0;
        for (n = 0; n < 65536; n = n + 1) begin
            @(posedge clk);
            if (r1) c[0] = c[0] + 1;  if (g1) c[1] = c[1] + 1;
            if (b1) c[2] = c[2] + 1;  if (w1) c[3] = c[3] + 1;
            if (r2) c[4] = c[4] + 1;  if (g2) c[5] = c[5] + 1;
            if (b2) c[6] = c[6] + 1;  if (w2) c[7] = c[7] + 1;
        end
        $display("  GM1 pins: R=%5d G=%5d B=%5d W=%5d   (expected %5d %5d %5d %5d)",
                 c[0], c[1], c[2], c[3], e(r1v), e(g1v), e(b1v), e(w1v));
        $display("  GM2 pins: R=%5d G=%5d B=%5d W=%5d   (expected %5d %5d %5d %5d)",
                 c[4], c[5], c[6], c[7], e(r2v), e(g2v), e(b2v), e(w2v));
        if (c[0] != e(r1v) || c[1] != e(g1v) || c[2] != e(b1v) || c[3] != e(w1v) ||
            c[4] != e(r2v) || c[5] != e(g2v) || c[6] != e(b2v) || c[7] != e(w2v)) begin
            errors = errors + 1; $display("  <-- WRONG");
        end
    end endtask

    initial begin
        #500000;                                 // GM2 + solo find out they are last

        $display("Test 1: LED before count -> answers with ID FF");   // [NEW]
        frame(1000, 2000, 3000, 4000,      5000, 6000, 7000, 8000);
        // set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 9'h180, 9'h000, 9'h028, 9'h176);   (old)
        set_exp8(9'h180, 9'h0FF, 9'h028, 9'h176, 9'h180, 9'h0FF, 9'h028, 9'h176);      // [NEW]
        check_dn(8);

        $display("Test 2: count segments 160 000 176");
        send9(9'h160); send9(9'h000); send9(9'h176); #1000000;
        // exp[0]=9'h1B0; exp[1]=9'h001; exp[2]=9'h176;   (old)
        // check_dn(3);                                     (old)
        set_exp8(9'h1B0, 9'h000, 9'h176, 9'h1B0, 9'h001, 9'h176, 0, 0);   // [NEW] every GM answers
        check_dn(6);                                                       // [NEW]
        $display("  GM1 my_id=%0d  GM2 my_id=%0d", gm1.my_id, gm2.my_id);  // [NEW]
        // if (gm1.my_id != 1 || gm2.my_id != 2) ...   (old)
        if (gm1.my_id != 0 || gm2.my_id != 1) begin errors = errors + 1; $display("  <-- WRONG id"); end  // [NEW]
        $display("  solo GM last answer: %h %h %h   (expected 1b0 000 176)",   // [NEW]
                 sgot[s_got-3], sgot[s_got-2], sgot[s_got-1]);
        if (sgot[s_got-3] !== 9'h1B0 || sgot[s_got-2] !== 9'h000 || sgot[s_got-1] !== 9'h176) begin  // [NEW]
            errors = errors + 1; $display("  <-- WRONG solo total");
        end
        $display("  D5..D8: GM1 leds_n[7:4]=%b  GM2 leds_n[7:4]=%b  (0 = on)", led1_n[7:4], led2_n[7:4]);

        $display("Test 3: LED frame, GM1 = hot pink, GM2 = blue + some white");
        frame(65025, 11025, 32400, 0,      0, 0, 65535, 10000);
        // set_exp8(9'h180, 9'h001, 9'h028, 9'h176, 9'h180, 9'h002, 9'h028, 9'h176);   (old)
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 9'h180, 9'h001, 9'h028, 9'h176);      // [NEW]
        check_dn(8);
        check(65025, 11025, 32400, 0,      0, 0, 65535, 10000);

        $display("Test 4: short frame (12 data bytes) -> only GM1 updates and answers");
        send9(9'h100);
        send16(500); send16(600); send16(700); send16(800);
        send16(9999); send16(9999);
        send9(9'h176); #1000000;
        // set_exp8(9'h180, 9'h001, 9'h028, 9'h176, 0, 0, 0, 0);   (old)
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 0, 0, 0, 0);      // [NEW]
        check_dn(4);
        check(500, 600, 700, 800,          0, 0, 65535, 10000);

        $display("Test 5: other command 170 -> nothing changes, no answer");
        send9(9'h170); send9(9'h000); send9(9'h176); #1000000;
        check_dn(0);
        // if (gm1.my_id != 1 || gm2.my_id != 2) ...   (old)
        if (gm1.my_id != 0 || gm2.my_id != 1) begin errors = errors + 1; $display("  <-- WRONG id changed"); end  // [NEW]

        if (errors == 0) $display("PASS"); else $display("FAIL  (%0d errors)", errors);
        $finish;
    end
endmodule

// fake CC_PLL, ONLY for simulation (yosys never sees this file)
// passes the clock straight through and says locked
module CC_PLL #(parameter REF_CLK = "", OUT_CLK = "", PERF_MD = "") (
    input  CLK_REF, CLK_FEEDBACK, USR_CLK_REF, USR_LOCKED_STDY_RST,
    output USR_PLL_LOCKED_STDY, USR_PLL_LOCKED,
    output CLK270, CLK180, CLK90, CLK0, CLK_REF_OUT
);
    assign CLK0 = CLK_REF;  assign CLK_REF_OUT = CLK_REF;
    assign USR_PLL_LOCKED = 1'b1;  assign USR_PLL_LOCKED_STDY = 1'b1;
    assign CLK90 = 1'b0;  assign CLK180 = 1'b0;  assign CLK270 = 1'b0;
endmodule

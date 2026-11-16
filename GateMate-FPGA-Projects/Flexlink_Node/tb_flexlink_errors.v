`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// tb_flexlink_errors.v  -  simulation only: error cases of the Flexlink node
//   same chain as tb_flexlink_node.v: PC -> GM1 -> GM2 (+ one GM alone)
//
//   Tests (numbers as in the hardware test plan, Chapter 6):
//     B1 count value FF        B2 count value FE        A1 count value 00
//     B3 two count values      B4 no count value        B5 control word as value
//     B7 count without EOP     C1 8 data bytes          C2 unfinished packet first
//     C6 two data bytes        C9 control word in data
//     data word outside a packet, EOP outside a packet, short glitch,
//     broken stop bit, forwarding delay
//   Prints PASS or FAIL.
// ---------------------------------------------------------------------------
module tb_flexlink_errors;
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


    // ---- extra: count words forwarded by GM1 on up_12 ----
    wire [8:0] f_word; wire f_valid; integer n_fwd = 0;
    uart_rx9 #(.CLKS_PER_BIT(50)) fwd_receiver (.clk(clk), .rx(up_12), .data(f_word), .valid(f_valid));
    always @(posedge clk) if (f_valid) n_fwd <= n_fwd + 1;

    task send9_badstop(input [8:0] v); begin
        pc_tx = 0; #BIT;
        for (i = 0; i < 9; i = i + 1) begin pc_tx = v[i]; #BIT; end
        pc_tx = 0; #BIT;               // stop bit = 0
        pc_tx = 1; #(2*BIT);
    end endtask
    task ids(input [7:0] a, input [7:0] b, input [8*20:1] name); begin
        $display("  IDs GM1=%h GM2=%h (expected %h %h)", gm1.my_id, gm2.my_id, a, b);
        if (gm1.my_id != a || gm2.my_id != b) begin errors = errors + 1; $display("  <-- WRONG id after %0s", name); end
    end endtask
    task led16; begin
        frame(1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000);
    end endtask
    integer f0; realtime t_in, t_out;

    initial begin
        #500000;
        $display("B1: count value FF");
        send9(9'h160); send9(9'h0FF); send9(9'h176); #1000000;
        exp[0]=9'h1B0; exp[1]=9'h0FF; exp[2]=9'h176; check_dn(3); ids(8'hFF, 8'hFF, "B1");
        $display("B2: count value FE");
        send9(9'h160); send9(9'h0FE); send9(9'h176); #1000000;
        set_exp8(9'h1B0, 9'h0FE, 9'h176, 9'h1B0, 9'h0FF, 9'h176, 0, 0); check_dn(6); ids(8'hFE, 8'hFF, "B2");
        $display("A1: count value 00");
        send9(9'h160); send9(9'h000); send9(9'h176); #1000000;
        set_exp8(9'h1B0, 9'h000, 9'h176, 9'h1B0, 9'h001, 9'h176, 0, 0); check_dn(6); ids(0, 1, "A1");
        $display("B3: two count values");
        send9(9'h160); send9(9'h000); send9(9'h004); send9(9'h176); #1000000; check_dn(0); ids(0, 1, "B3");
        $display("B4: no count value");
        send9(9'h160); send9(9'h176); #1000000; check_dn(0); ids(0, 1, "B4");
        $display("B5: control word 150 as count value");
        send9(9'h160); send9(9'h150); send9(9'h176); #1000000; check_dn(0); ids(0, 1, "B5");
        $display("B7: count without EOP, then LED packet");
        send9(9'h160); send9(9'h000); led16;
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 9'h180, 9'h001, 9'h028, 9'h176); check_dn(8); ids(0, 1, "B7");
        $display("C1: LED packet with 8 data bytes");
        send9(9'h100); send16(111); send16(222); send16(333); send16(444); send9(9'h176); #1000000;
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 0,0,0,0); check_dn(4);
        check(111, 222, 333, 444, 5000, 6000, 7000, 8000);
        $display("C2: unfinished packet 100 20 30, then LED packet");
        send9(9'h100); send9(9'h020); send9(9'h030); led16;
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 9'h180, 9'h001, 9'h028, 9'h176); check_dn(8);
        check(1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000);
        $display("C6: two data bytes");
        send9(9'h100); send9(9'h0FF); send9(9'h0FF); send9(9'h176); #1000000; check_dn(0);
        check(1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000);
        $display("C9: control word 110 inside LED data");
        send9(9'h100); send9(9'h020); send9(9'h030); send9(9'h110);
        send16(9); send16(9); send16(9); send16(9); send16(9); send16(9); send16(9); send16(9);
        send9(9'h176); #1000000; check_dn(0);
        check(1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000);
        $display("Data word outside a packet (055)");
        f0 = n_fwd; send9(9'h055); #200000;
        $display("  forwarded by GM1: %0d words (expected 0)", n_fwd - f0); if (n_fwd != f0) errors = errors + 1; check_dn(0);
        $display("EOP outside a packet");
        f0 = n_fwd; send9(9'h176); #200000;
        $display("  forwarded by GM1: %0d words (expected 0)", n_fwd - f0); if (n_fwd != f0) errors = errors + 1; check_dn(0);
        $display("Short glitch (200 ns low)");
        f0 = n_fwd; pc_tx = 0; #200; pc_tx = 1; #200000;
        $display("  forwarded by GM1: %0d words (expected 0)", n_fwd - f0); if (n_fwd != f0) errors = errors + 1; check_dn(0);
        $display("Broken stop bit in data byte 12 (GM2 part)");
        send9(9'h100);
        send16(1000); send16(2000); send16(3000); send16(4000);
        send16(5000); send9(9'h017); send9_badstop(9'h070); send16(7000); send16(8000);
        send9(9'h176); #1000000;
        set_exp8(9'h180, 9'h000, 9'h028, 9'h176, 0,0,0,0); check_dn(4);
        $display("Forwarding delay");
        fork
            begin send9(9'h100); end
            begin @(negedge pc_tx); t_in = $realtime; @(negedge up_12); t_out = $realtime; end
        join
        send9(9'h176); #1000000;
        $display("  delay start edge in -> start edge out = %0.3f us", (t_out - t_in)/1000.0);
        n_seen = n_got;
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

module four_led_top #(
    // Clock cycles per UART bit = 50 MHz / baud rate.
    //   115200 baud -> 434        1 MBaud (Flexlink target) -> 50
    parameter CLKS_PER_BIT = 434
)(
    input  wire       clk,      // 10 MHz on-board oscillator
    input  wire       rx,       // serial data from the adapter's TXD pin
    output wire [7:0] leds_n,   // on-board LEDs D1..D8 (0 = on)
    output wire       red,      // to the external LED driver stage
    output wire       green,
    output wire       blue,
    output wire       white
);

    // ------------------------------------------------------------------
    // 1) Clock: the 10 MHz oscillator is multiplied up to 50 MHz.
    //    A faster clock gives a faster PWM: 50 MHz / 65536 = 763 Hz,
    //    which is above the 400 Hz minimum (no visible flicker).
    // ------------------------------------------------------------------
    wire clk_sys;
    wire pll_locked;

    CC_PLL #(
        .REF_CLK ("10.0"),
        .OUT_CLK ("50.0"),
        .PERF_MD ("ECONOMY")
    ) pll_inst (
        .CLK_REF             (clk),
        .CLK_FEEDBACK        (1'b0),
        .USR_CLK_REF         (1'b0),
        .USR_LOCKED_STDY_RST (1'b0),
        .USR_PLL_LOCKED_STDY (),
        .USR_PLL_LOCKED      (pll_locked),
        .CLK270              (),
        .CLK180              (),
        .CLK90               (),
        .CLK0                (clk_sys),
        .CLK_REF_OUT         ()
    );

    // ------------------------------------------------------------------
    // 2) UART receiver: turns the serial line into 9-bit symbols.
    //    'valid' is high for one clock whenever a new symbol is ready.
    // ------------------------------------------------------------------
    wire [8:0] symbol;
    wire       valid;

    uart_rx9 #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk   (clk_sys),
        .rx    (rx),
        .data  (symbol),
        .valid (valid)
    );

    // ------------------------------------------------------------------
    // 3) Frame decoder
    // ------------------------------------------------------------------
    localparam [8:0] SOP_RGBW = 9'h100;
    localparam [8:0] EOP      = 9'h176;
    localparam [3:0] BYTES_PER_FRAME = 4'd8;   // 4 channels x 2 bytes

    reg        in_frame   = 1'b0;   // 1 while we are between SOP and EOP
    reg  [3:0] byte_count = 4'd0;   // data bytes received in this frame
    reg [63:0] frame_data = 64'd0;  // the bytes collected so far

    reg [15:0] level_red   = 16'd0; // values currently shown on the LEDs
    reg [15:0] level_green = 16'd0;
    reg [15:0] level_blue  = 16'd0;
    reg [15:0] level_white = 16'd0;

    always @(posedge clk_sys) begin
        if (valid) begin
            if (symbol == EOP) begin
                // End of frame: apply only if the frame was complete.
                if (in_frame && byte_count == BYTES_PER_FRAME) begin
                    level_red   <= frame_data[63:48];
                    level_green <= frame_data[47:32];
                    level_blue  <= frame_data[31:16];
                    level_white <= frame_data[15:0];
                end
                in_frame <= 1'b0;
            end
            else if (symbol[8]) begin
                // Any other control symbol starts a new frame.
                // Only the RGBW command is accepted; others are ignored.
                in_frame   <= (symbol == SOP_RGBW);
                byte_count <= 4'd0;
            end
            else if (in_frame) begin
                // Data byte: push it in from the right.
                frame_data <= {frame_data[55:0], symbol[7:0]};
                // Count up to 9 at most. 9 means "too many bytes",
                // and such a frame will be rejected at EOP.
                if (byte_count <= BYTES_PER_FRAME)
                    byte_count <= byte_count + 4'd1;
            end
        end
    end

    // ------------------------------------------------------------------
    // 4) PWM: one shared 16-bit counter, one compare per channel.
    //
    //    The output is on while counter < level, so the duty cycle is
    //    level / 65536. Level 65535 is treated as "always on" so that
    //    full brightness really means 100 %.
    // ------------------------------------------------------------------
    reg [15:0] pwm_counter = 16'd0;
    always @(posedge clk_sys)
        pwm_counter <= pwm_counter + 16'd1;

    reg pwm_red   = 1'b0;
    reg pwm_green = 1'b0;
    reg pwm_blue  = 1'b0;
    reg pwm_white = 1'b0;

    // Registered outputs give clean edges. All LEDs stay off until
    // the PLL is locked.
    always @(posedge clk_sys) begin
        pwm_red   <= pll_locked && ((level_red   == 16'hFFFF) || (pwm_counter < level_red));
        pwm_green <= pll_locked && ((level_green == 16'hFFFF) || (pwm_counter < level_green));
        pwm_blue  <= pll_locked && ((level_blue  == 16'hFFFF) || (pwm_counter < level_blue));
        pwm_white <= pll_locked && ((level_white == 16'hFFFF) || (pwm_counter < level_white));
    end

    // ------------------------------------------------------------------
    // 5) Outputs
    // ------------------------------------------------------------------
    assign red   = pwm_red;
    assign green = pwm_green;
    assign blue  = pwm_blue;
    assign white = pwm_white;

    // On-board LEDs are active low (0 = on). D5..D8 are not used.
    assign leds_n = { 4'b1111,
                      ~pwm_white, ~pwm_blue, ~pwm_green, ~pwm_red };

endmodule

module top(
    input clk,
    output led
);

    // Using a 24-bit counter.
    // If the clock is 10 MHz, a 24-bit counter overflows at:
    // 10,000,000 / (2^24) ≈ 0.6 Hz (will blink slightly slower than 1 second)
    reg [23:0] counter = 0;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    // The most significant bit (MSB) toggles the LED
    assign led = counter[23];

endmodule

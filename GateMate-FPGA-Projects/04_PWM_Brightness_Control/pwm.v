module top(
    input clk,
    output [7:0] leds
);

    // --- Timer Logic ---
    // A 24-bit counter at 10MHz overflows every ~1.67 seconds
    reg [23:0] delay_timer = 0;

    // --- State Machine ---
    // 0: OFF, ..., 7: 100% Bright
    reg [2:0] brightness_state = 7; // Start at full brightness

    always @(posedge clk) begin
        delay_timer <= delay_timer + 1;
        
        // When the timer rolls over (~every 1.67 seconds)
        if (delay_timer == 24'd0) begin
            brightness_state <= brightness_state - 1; // Reduce brightness. When 0, it wraps back to 7!
        end
    end

    // --- PWM Generator ---
    // A fast counter that constantly rolls over.
    // At 10MHz, an 8-bit counter (0 to 255) overflows ~39,000 times a second!
    reg [7:0] pwm_counter = 0;
    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1;
    end

    // --- LED Output Logic ---
    reg led_out = 0;
    always @(*) begin
        case (brightness_state)
            3'd0: led_out = 0;                                     // 0%
            3'd1: led_out = (pwm_counter < 8'd36)  ? 1'b1 : 1'b0;  // 14%
            3'd2: led_out = (pwm_counter < 8'd72)  ? 1'b1 : 1'b0;  // 28%
            3'd3: led_out = (pwm_counter < 8'd108) ? 1'b1 : 1'b0;  // 42%
            3'd4: led_out = (pwm_counter < 8'd144) ? 1'b1 : 1'b0;  // 57%
            3'd5: led_out = (pwm_counter < 8'd180) ? 1'b1 : 1'b0;  // 71%
            3'd6: led_out = (pwm_counter < 8'd216) ? 1'b1 : 1'b0;  // 85%
            3'd7: led_out = 1;                                     // 100%
        endcase
    end

    // Assign the same brightness output to all 8 LEDs using replication
    assign leds = {8{led_out}};

endmodule

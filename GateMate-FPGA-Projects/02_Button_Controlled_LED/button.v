module top(
    input clk,
    input btn,
    output reg led
);

    // Initial state
    initial begin
        led = 0;
    end

    // The push button on the GateMate Eval board is Active Low
    // (It reads 1 when unpressed, 0 when pressed)
    // We invert it here so that '1' means pressed, making the logic easier.
    wire btn_pressed = ~btn;

    // --- Debouncing Logic ---
    // A mechanical button bounces rapidly when pressed. We need to wait for the signal to stabilize.
    // A 16-bit counter at 10MHz overflows every ~6.5ms, which is a good debounce delay.
    reg [15:0] debounce_counter = 0;
    reg btn_state = 0;      // Current stabilized state of the button
    reg prev_btn_state = 0; // Previous stabilized state to detect edges

    always @(posedge clk) begin
        // If the raw button input is different from our stabilized state, start counting
        if (btn_pressed != btn_state) begin
            debounce_counter <= debounce_counter + 1;
            
            // If the signal has remained stable long enough for the counter to fill up
            if (debounce_counter == 16'hFFFF) begin
                btn_state <= btn_pressed; // Register the new stable state
                debounce_counter <= 0;
            end
        end else begin
            debounce_counter <= 0; // Reset counter if button bounces back to old state
        end
    end

    // --- Toggle Logic ---
    // We only want to toggle the LED exactly when the button is first pressed down
    always @(posedge clk) begin
        // Keep track of the previous state
        prev_btn_state <= btn_state;
        
        // Detect a rising edge: the button was unpressed last clock cycle, and is pressed this cycle
        if (btn_state == 1 && prev_btn_state == 0) begin
            led <= ~led; // Flip the LED state (0->1 or 1->0)
        end
    end

endmodule

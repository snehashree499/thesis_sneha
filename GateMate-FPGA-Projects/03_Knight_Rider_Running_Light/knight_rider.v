module top(
    input clk,
    output reg [7:0] leds
);

    // Start with the first LED turned on
    initial begin
        leds = 8'b00000001;
    end

    // Clock divider to slow down the movement
    // 10MHz clock. A 22-bit counter overflows every ~0.4 seconds
    reg [21:0] delay_counter = 0;
    
    // Direction: 0 means shifting left (up), 1 means shifting right (down)
    reg direction = 0;

    always @(posedge clk) begin
        delay_counter <= delay_counter + 1;
        
        // When the delay counter rolls over to 0 (every ~0.4 seconds)
        if (delay_counter == 22'd0) begin
            if (direction == 0) begin
                // Shift the lit LED one position to the left
                leds <= leds << 1;
                
                // If the next shift would push the bit out entirely (we are currently at the 2nd to last LED)
                if (leds == 8'b01000000) begin
                    direction <= 1; // Change direction to go back down
                end
            end else begin
                // Shift the lit LED one position to the right
                leds <= leds >> 1;
                
                // If the next shift would push the bit out entirely (we are currently at the 2nd LED)
                if (leds == 8'b00000010) begin
                    direction <= 0; // Change direction to go back up
                end
            end
        end
    end

endmodule

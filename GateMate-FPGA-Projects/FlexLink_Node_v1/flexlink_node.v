// ---------------------------------------------------------------------------
// flexlink_node.v  -  ONE GateMate = ONE RGBW segment
//   LED data (uplink + downlink answer) and Count Segments in one file.
//   SAME bitstream on every GateMate, the ID comes from Count Segments.
//
//   UPLINK   (PC/PIC -> segments)
//      PC --TTL Tx--> [GM1 pin1] ... [GM1 pin3] --> [GM2 pin1] ... [GM2 pin3] --> (nothing)
//   DOWNLINK (segments -> PC/PIC)
//      PC <--TTL Rx-- [GM1 pin2] ... [GM1 pin4] <-- [GM2 pin2] ... [GM2 pin4] <-- (nothing, pull-down)
//
//   Packets (115200 baud, 9 data bits):
//      Count   up : 160 | a | 176          a = segments before me, I pass on a+1
//      Count   dn : 1B0 | total | 176      only the LAST GM answers
//      LED     up : 100 | R G B W of GM1 (8 bytes) | R G B W of GM2 (8 bytes) | 176
//      LED     dn : 180 | my_id | temp | 176   every GM answers after a good LED frame
//
//   Send Count first, then LED. Before Count my_id is 0.
//
//   Pins (PmodA):  1 = up_rx   2 = dn_tx   3 = up_tx   4 = dn_rx (PULLDOWN)
//                  7..10 = SEG1..SEG4 (red, green, blue, white)
//   On-board D1..D4 = PWM of R G B W,  D5..D8 = my_id in binary
// ---------------------------------------------------------------------------
module flexlink_node #(
    parameter       CLKS_PER_BIT = 50,     // 50 MHz / 115200 baud   (1 MBaud -> 50)
    parameter [7:0] MY_TEMP      = 8'd40    // temperature, fixed for now (1 = 1 deg C)
)(
    input  wire       clk,            // 10 MHz on-board oscillator
    // input wire pot,
    input  wire       up_rx,          // pin 1: from TTL Tx (GM1) / from previous GM pin 3
    output wire       dn_tx,          // pin 2: to TTL Rx (GM1) / to previous GM pin 4
    output wire       up_tx,          // pin 3: to next GM pin 1
    input  wire       dn_rx,          // pin 4: from next GM pin 2
    output wire [7:0] leds_n,         // on-board D1..D8 (0 = on)
    output wire       seg1,           // pin 7  : red
    output wire       seg2,           // pin 8  : green
    output wire       seg3,           // pin 9  : blue
    output wire       seg4,           // pin 10 : white
    output wire       vref_2v5
);

    // Flexlink commands
    localparam [8:0] LED_UP_SOP = 9'h100;   // LED data PC -> segments
    localparam [8:0] LED_DN_SOP = 9'h180;   // LED answer segments -> PC
    localparam [8:0] CNT_UP_SOP = 9'h160;   // count segments PC -> segments
    localparam [8:0] CNT_DN_SOP = 9'h1B0;   // count answer segments -> PC
    localparam [8:0] FL_EOP     = 9'h176;   // end of packet

    // ------------------------------------------------------------------
    // 1) Clock: 10 MHz -> 50 MHz   (50,000,000 / 65,536 = 763 Hz PWM, above 400 Hz)
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
        .USR_PLL_LOCKED      (pll_locked),  // 1 when 50 MHz is stable
        .CLK270              (),
        .CLK180              (),
        .CLK90               (),
        .CLK0                (clk_sys),
        .CLK_REF_OUT         ()
    );

    // ------------------------------------------------------------------
    // 2) UART receiver (uplink), pin 1
    // ------------------------------------------------------------------
    wire [8:0] up_data;
    wire       up_valid;   // 1-clock pulse, new up_data arrived

    uart_rx9 #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_up_rx (
        .clk(clk_sys), .rx(up_rx), .data(up_data), .valid(up_valid)
    );

    // ------------------------------------------------------------------
    // 3) Decoder: for every symbol keep it or pass it on
    //    LED   : keep my first 8 bytes, pass on the rest
    //    Count : first data byte is a -> my_id = a + 1, pass on a + 1 instead of a
    // ------------------------------------------------------------------
    localparam [3:0] MY_BYTES = 4'd8;   // 4 colours x 2 bytes. 8 = 1000 -> 4 bits

    reg        in_frame   = 1'b0;   // 1 between SOP and EOP
    reg        is_led     = 1'b0;   // this frame is LED data (100)
    reg        is_cnt     = 1'b0;   // this frame is count segments (160)
    reg        cnt_got    = 1'b0;   // count value already received in this frame
    reg  [3:0] keep_count = 4'd0;   // how many of my bytes I kept (0..8)
    reg [63:0] frame_data = 64'd0;  // my 8 bytes
    reg  [7:0] my_id      = 8'hFF;   // FF = not counted yet, after count: GM1 = 00, GM2 = 01 ..

    reg [15:0] level_red   = 16'd0; // values shown on my LEDs
    reg [15:0] level_green = 16'd0;
    reg [15:0] level_blue  = 16'd0;
    reg [15:0] level_white = 16'd0;

    reg  [8:0] fwd_data  = 9'd0;    // symbol to pass on to the next GM
    reg        fwd_valid = 1'b0;    // pulse: put fwd_data in the queue
    reg        led_done  = 1'b0;    // pulse: good LED frame -> send LED answer
    reg        cnt_done  = 1'b0;    // pulse: count frame finished -> answer if I am last
    reg        cnt_ovf   = 1'b0;    // count value was FF -> overflow, stop counting here
    reg        cnt_extra  = 1'b0;   // more than 1 data byte in the count packet -> wrong
    reg  [7:0] temp_id    = 8'hFF;   // id from this count, taken only if the packet is ok
    // [OVF] hold back the count SOP till the count value is checked -> nothing goes to the next GM on overflow
    reg        cnt_pend   = 1'b0;   // [OVF] 1 = send the held-back count value in the next clock
    reg  [8:0] cnt_next   = 9'd0;   // [OVF] the count value (a+1) waiting to be sent

    always @(posedge clk_sys) begin
        fwd_valid <= 1'b0;
        led_done  <= 1'b0;
        cnt_done  <= 1'b0;


        if (up_valid) begin
            if (up_data == FL_EOP) begin
                if (in_frame && is_led && keep_count == MY_BYTES) begin   // got all my 8 bytes // Check: GM got all 8 of its bytes before updating
                    level_red   <= frame_data[63:48];
                    level_green <= frame_data[47:32];
                    level_blue  <= frame_data[31:16];
                    level_white <= frame_data[15:0];
                    led_done    <= 1'b1;    //only answer after a good frame
                end
                if (in_frame && is_cnt && cnt_got && !cnt_extra) begin //incase to abort remove cnt_extra check
                    my_id    <= temp_id;   // packet was ok -> take the new id now
                        //fwd_data  <= CNT_UP_SOP;                     // [OVF] value is ok -> now send the held-back SOP
                    cnt_done <= 1'b1;
                end
                // EOP: pass it on, then act on the frame
                // if (in_frame) begin                                       // [OVF] old line
                if (in_frame) begin   // [OVF] no EOP if the count SOP was never sent
                    fwd_data  <= FL_EOP;
                    fwd_valid <= 1'b1;
                end
                in_frame <= 1'b0;
            end
            else if (up_data[8]) begin
                // any SOP: pass it on, start a new frame
                fwd_data   <= up_data;
                fwd_valid  <= 1'b1;                    // [OVF] old line
               // fwd_valid  <= (up_data != CNT_UP_SOP);   // [OVF] count SOP is held back till the value is checked
                in_frame   <= 1'b1;
                is_led     <= (up_data == LED_UP_SOP);
                is_cnt     <= (up_data == CNT_UP_SOP);
                cnt_got    <= 1'b0;  // cnt_got = 0  → I have NOT received the count value yet in this packet
                                     // cnt_got = 1  → I already received the count value
                cnt_ovf    <= 1'b0; // new frame, no overflow yet
                cnt_extra  <= 1'b0;   // new frame, no extra bytes yet
                keep_count <= 4'd0;
            end
            else if (in_frame) begin
                if (is_led && keep_count < MY_BYTES) begin
                    // mine, push in from the right
                    frame_data <= {frame_data[55:0], up_data[7:0]};
                    keep_count <= keep_count + 4'd1;
                end
                else if (is_cnt && !cnt_got) begin // (Is this a count packet && I have not received a count value yet)
                                                   // count value a: I am segment a, next GM gets a+1
                    cnt_got   <= 1'b1;  // I have received the count value, so I will not process any more count values in this frame
                    temp_id     <= up_data[7:0];  // wait till EOP, take it only if packet is ok
                        
                    if (up_data[7:0] == 8'hFF) begin // overflow, stop counting here
                        cnt_ovf   <= 1'b1;
                    end
                    else begin
                        fwd_data  <= {1'b0, up_data[7:0] + 8'd1};   // next GM gets +1     // [OVF] old line
                        fwd_valid <= 1'b1;   
                    end 
                end
                    /*// This logic is to abort the packet if a 2nd data byte is received in a count packet.
                    else begin
                        if (is_cnt) begin
                        // 2nd data byte in a count packet -> ABORT this packet
                            fwd_data  <= up_data;   // pass this byte on, so the next GM aborts too
                            fwd_valid <= 1'b1;
                            in_frame  <= 1'b0;      // stop: ignore the rest of this packet (also the EOP)
                        end
                    else begin
                        // not mine, pass it on
                        fwd_data  <= up_data;
                        fwd_valid <= 1'b1;
                    end
                end */
                    /* This below logic is to keep FF as the my_id for the GM that receives FF, but it is not needed as we are not counting beyond 255 segments.
                    Eg 1: cnt_got = 1
                        my_id   = 05
                        05 != FF ? yes → fwd_data = {0, 05 + 1} = 0x006 → sent to the next GM
                        EOP → answers 1B0 05 176
                    Eg 2: cnt_got = 1
                        my_id   = FF
                        FF != FF ? no → nothing passed on (FF + 1 would wrap to 00)
                        EOP → answers 1B0 FF 176
                        next GM gets only 160 … 176 (SOP and EOP) → no data → stays silent  

                    else if (is_cnt && !cnt_got) begin
                    cnt_got <= 1'b1;
                        my_id   <= up_data[7:0];
                            if (up_data[7:0] != 8'hFF) begin
                                fwd_data  <= {1'b0, up_data[7:0] + 8'd1};   // next GM gets +1 
                                fwd_valid <= 1'b1;
                            end*/
                else begin
                    // not mine, pass it on
                    if (is_cnt) begin
                        cnt_extra <= 1'b1;
                    end
                    fwd_data  <= up_data;
                    fwd_valid <= 1'b1;   // [OVF] after an overflow pass nothing on
                    
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // 4) Uplink forward: queue -> UART transmitter -> pin 3
    // ------------------------------------------------------------------
    wire [8:0] up_q_data;
    wire       up_q_empty;
    wire       up_busy;
    reg        up_send = 1'b0;

    fifo9 u_up_q (
        .clk(clk_sys), .wr(fwd_valid), .din(fwd_data),
        .rd(up_send), .dout(up_q_data), .empty(up_q_empty)
    );

    always @(posedge clk_sys)
        up_send <= !up_q_empty && !up_busy && !up_send;   // something waiting + transmitter free

    uart_tx9 #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_up_tx (   // sends to GM2 pin 1 from GM1 pin 3
        .clk(clk_sys), .send(up_send), .data(up_q_data), .tx(up_tx), .busy(up_busy)
    );

    // ------------------------------------------------------------------
    // 5) Am I the LAST GM?   (pin 4 has a PULLDOWN in the .ccf)
    //    next GM connected -> its dn_tx idles HIGH -> dn_rx HIGH -> not last
    //    nothing connected -> pulldown -> dn_rx LOW for more than 2 words -> last
    // ------------------------------------------------------------------
    localparam LAST_TIME = CLKS_PER_BIT * 22;   // 2 words x 11 bits

    reg        dn_s1 = 1'b0, dn_s2 = 1'b0;      // 2 flip-flops, make dn_rx safe
    reg [15:0] low_cnt = 16'd0;
    reg        is_last = 1'b0;

    always @(posedge clk_sys) begin
        dn_s1 <= dn_rx;
        dn_s2 <= dn_s1;
        if (dn_s2) begin
            low_cnt <= 16'd0;
            is_last <= 1'b0;
        end
        else if (low_cnt == LAST_TIME)
            is_last <= 1'b1;
        else
            low_cnt <= low_cnt + 16'd1;
    end

    // ------------------------------------------------------------------
    // 6) Downlink: my answer first, then the next GM's answers
    //    never mix packets, if I am passing on a packet from the next GM
    //    I finish it (till its EOP) before my own
    // ------------------------------------------------------------------
    wire [8:0] dn_data;
    wire       dn_valid;

    uart_rx9 #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_dn_rx (
        .clk(clk_sys), .rx(dn_rx), .data(dn_data), .valid(dn_valid)
    );

    wire [8:0] dn_q_data;
    wire       dn_q_empty;
    reg        dn_q_read = 1'b0;

    fifo9 u_dn_q (
        .clk(clk_sys), .wr(dn_valid), .din(dn_data),
        .rd(dn_q_read), .dout(dn_q_data), .empty(dn_q_empty)
    );

    // my answer word by word
    //   LED   : 180 | my_id | temp | 176     reply_w 0..3
    //   Count : 1B0 | my_id | 176            reply_w 0..2   (last GM: my_id = total)
    reg       reply_pending = 1'b0;   // 1 = still have to send my answer
    reg       reply_is_cnt  = 1'b0;   // 1 = count answer, 0 = LED answer
    reg [2:0] reply_w       = 3'd0;   // which word is next

    wire [2:0] reply_last = reply_is_cnt ? 3'd2 : 3'd3;   // index of my EOP

    wire [8:0] reply_word =
        (reply_w == 3'd0)       ? (reply_is_cnt ? CNT_DN_SOP : LED_DN_SOP) :
        (reply_w == 3'd1)       ? {1'b0, my_id} :
        (reply_w == reply_last) ? FL_EOP :
                                  {1'b0, MY_TEMP};

    reg  [8:0] dn_send_data   = 9'd0;
    reg        dn_send        = 1'b0;   // pulse: send dn_send_data
    wire       dn_busy;
    reg        passing_packet = 1'b0;   // 1 = in the middle of a next-GM packet

    always @(posedge clk_sys) begin
        dn_send   <= 1'b0;
        dn_q_read <= 1'b0;

        if (led_done) begin
            reply_pending <= 1'b1;
            reply_is_cnt  <= 1'b0;
            reply_w       <= 3'd0;
        end
        else if (cnt_done) begin
            reply_pending <= 1'b1;
            reply_is_cnt  <= 1'b1;
            reply_w       <= 3'd0;
        end
        else if (!dn_busy && !dn_send && !dn_q_read) begin   // transmitter free
            if (reply_pending && !passing_packet) begin
                // next word of MY answer
                dn_send_data <= reply_word;
                dn_send      <= 1'b1;
                reply_w      <= reply_w + 3'd1;
                if (reply_w == reply_last)
                    reply_pending <= 1'b0;                  // my EOP sent, done
            end
            else if (!dn_q_empty) begin
                // pass on one word from the next GM
                dn_send_data   <= dn_q_data;
                dn_send        <= 1'b1;
                dn_q_read      <= 1'b1;
                passing_packet <= (dn_q_data != FL_EOP);    // EOP -> packet finished
            end
        end
    end

    uart_tx9 #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_dn_tx (
        .clk(clk_sys), .send(dn_send), .data(dn_send_data), .tx(dn_tx), .busy(dn_busy)
    );

    // ------------------------------------------------------------------
    // 7) PWM: one 16-bit counter, one compare per colour (763 Hz)
    //    65535 = always on. LEDs off till the PLL locks.
    // ------------------------------------------------------------------
    reg [15:0] pwm_counter = 16'd0;
    always @(posedge clk_sys)
        pwm_counter <= pwm_counter + 16'd1;

    reg pwm_red = 1'b0, pwm_green = 1'b0, pwm_blue = 1'b0, pwm_white = 1'b0;

    always @(posedge clk_sys) begin
        pwm_red   <= pll_locked && ((level_red   == 16'hFFFF) || (pwm_counter < level_red));
        pwm_green <= pll_locked && ((level_green == 16'hFFFF) || (pwm_counter < level_green));
        pwm_blue  <= pll_locked && ((level_blue  == 16'hFFFF) || (pwm_counter < level_blue));
        pwm_white <= pll_locked && ((level_white == 16'hFFFF) || (pwm_counter < level_white));
    end

    // ------------------------------------------------------------------
    // 8) Outputs
    // ------------------------------------------------------------------
    assign seg1 = pwm_red; // For Pot: pwm_red * pot_value
    assign seg2 = pwm_green; // For Pot: pwm_green * pot_value
    assign seg3 = pwm_blue; // For Pot: pwm_blue * pot_value
    assign seg4 = pwm_white; // For Pot: pwm_white * pot_value
    assign vref_2v5 = 1'b1;  // 2.5V reference for the LEDs

    // D1..D4 = PWM,  D5..D8 = my_id (GM1 -> D5 on, GM2 -> D6 on)
    assign leds_n = { ~my_id[3:0], ~pwm_white, ~pwm_blue, ~pwm_green, ~pwm_red };

endmodule


// ---------------------------------------------------------------------------
// uart_rx9 : receives ONE 9-bit symbol (1 start, 9 data LSB first, 1 stop)
//   wait for start bit, go to the middle of the bit, then sample every bit time
//   valid only if the stop bit is 1
// ---------------------------------------------------------------------------
module uart_rx9 #(parameter CLKS_PER_BIT = 434) (
    input  wire       clk,
    input  wire       rx,
    output reg  [8:0] data  = 9'd0,
    output reg        valid = 1'b0      // 1-clock pulse, data is new
);
    reg rx_meta = 1'b1, rx_sync = 1'b1; // 2 flip-flops, rx is not in step with our clock
    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg  [1:0] state   = IDLE;
    reg [15:0] clk_cnt = 16'd0;
    reg  [3:0] bit_idx = 4'd0;

    always @(posedge clk) begin
        valid <= 1'b0;
        case (state)
            IDLE:  if (rx_sync == 1'b0) begin state <= START; clk_cnt <= 16'd0; end

            START: if (clk_cnt == CLKS_PER_BIT/2 - 1) begin       // middle of start bit
                       clk_cnt <= 16'd0;
                       bit_idx <= 4'd0;
                       state   <= (rx_sync == 1'b0) ? DATA : IDLE;
                   end else clk_cnt <= clk_cnt + 16'd1;

            DATA:  if (clk_cnt == CLKS_PER_BIT - 1) begin         // middle of each data bit
                       clk_cnt       <= 16'd0;
                       data[bit_idx] <= rx_sync;
                       if (bit_idx == 4'd8) state <= STOP;
                       bit_idx <= bit_idx + 4'd1;
                   end else clk_cnt <= clk_cnt + 16'd1;

            STOP:  if (clk_cnt == CLKS_PER_BIT - 1) begin         // stop bit must be 1
                       clk_cnt <= 16'd0;
                       state   <= IDLE;
                       valid   <= (rx_sync == 1'b1);
                   end else clk_cnt <= clk_cnt + 16'd1;
        endcase
    end
endmodule


// ---------------------------------------------------------------------------
// uart_tx9 : sends ONE 9-bit symbol (1 start, 9 data LSB first, 1 stop) = 11 bits
// ---------------------------------------------------------------------------
module uart_tx9 #(parameter CLKS_PER_BIT = 434) (
    input  wire       clk,
    input  wire       send,             // 1-clock pulse: send data now
    input  wire [8:0] data,
    output reg        tx = 1'b1,        // line HIGH when idle
    output wire       busy
);
    reg [10:0] shift     = 11'h7FF;     // {stop, data[8:0], start}
    reg  [3:0] bits_left = 4'd0;
    reg [15:0] clk_cnt   = 16'd0;
    assign busy = (bits_left != 0);

    always @(posedge clk) begin
        if (!busy) begin
            if (send) begin
                shift     <= {1'b1, data, 1'b0};
                bits_left <= 4'd11;
                clk_cnt   <= 16'd0;
            end
        end else if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt   <= 16'd0;
            shift     <= {1'b1, shift[10:1]};   // next bit
            bits_left <= bits_left - 4'd1;
        end else
            clk_cnt <= clk_cnt + 16'd1;
        tx <= busy ? shift[0] : 1'b1;
    end
endmodule


// ---------------------------------------------------------------------------
// fifo9 : small queue of 8 x 9-bit values (first in, first out)
//   holds a value when the transmitter is still busy, so nothing gets lost
// ---------------------------------------------------------------------------
module fifo9 (
    input  wire       clk,
    input  wire       wr,               // put din in
    input  wire [8:0] din,
    input  wire       rd,               // take the oldest out
    output wire [8:0] dout,             // oldest value
    output wire       empty
);
    reg [8:0] mem [0:7];
    reg [3:0] wp = 0, rp = 0;           // 1 extra bit to tell full from empty
    assign empty = (wp == rp);
    assign dout  = mem[rp[2:0]];
    always @(posedge clk) begin
        if (wr && (wp - rp) != 8) begin mem[wp[2:0]] <= din; wp <= wp + 1; end
        if (rd && !empty) rp <= rp + 1;
    end
endmodule

# ============================================================================
#  send_4_fade.py  -  smooth fade on all four channels, until Ctrl + C
# ============================================================================
#
#  Red + blue fade in while green + white fade out, then the other way round.
#  A new frame is sent for every step, so this also shows that the receiver
#  handles a continuous stream of frames.
#
#  Run:   python send_4_fade.py        stop with Ctrl + C (all LEDs go off)
#
#  Needs pyserial once:  pip install pyserial
# ============================================================================

import time
import serial

PORT  = "COM3"      # serial adapter port (check Device Manager if it changes)
BAUD  = 115200      # must match CLKS_PER_BIT in 4_LED_top.v (115200 -> 434)
STEPS = 256         # brightness steps in one fade
DELAY = 0.01        # pause after each step in seconds (bigger = slower fade)


# ----------------------------------------------------------------------------
#  How the 9th bit is made (same as in send_4_value.py)
#      MARK  parity -> 9th bit = 1  (SOP, EOP)
#      SPACE parity -> 9th bit = 0  (data bytes)
# ----------------------------------------------------------------------------
def send_group(ser, byte_list, ninth_bit):
    ser.flush()          # wait until the previous bytes have left
    time.sleep(0.002)    # small extra time for the adapter's own buffer
    ser.parity = serial.PARITY_MARK if ninth_bit else serial.PARITY_SPACE
    ser.write(bytes(byte_list))


def split16(value):
    """16-bit value -> [high byte, low byte]"""
    return [value >> 8, value & 0xFF]


def send_frame(ser, red, green, blue, white):
    """[0x100]  R_hi R_lo  G_hi G_lo  B_hi B_lo  W_hi W_lo  [0x176]"""
    data = split16(red) + split16(green) + split16(blue) + split16(white)
    send_group(ser, [0x00], 1)   # 0x100  start of packet
    send_group(ser, data,   0)   # 8 data bytes
    send_group(ser, [0x76], 1)   # 0x176  end of packet


def brightness(step):
    """
    Step 0..255 -> PWM level 0..65025.

    The eye is much more sensitive to changes in dim light than in bright
    light. Squaring the step keeps the changes small at the dark end, so the
    fade looks even instead of jumping quickly to "bright".
    """
    return step * step


def main():
    ser = serial.Serial(PORT, BAUD, bytesize=8,
                        parity=serial.PARITY_SPACE, stopbits=1)
    print("fading... press Ctrl + C to stop")

    # One full cycle: step goes 0 -> 255, then 255 -> 0
    one_cycle = list(range(STEPS)) + list(range(STEPS - 1, -1, -1))

    try:
        while True:
            for step in one_cycle:
                up   = brightness(step)                # rising channel
                down = brightness(STEPS - 1 - step)    # falling channel
                send_frame(ser, up, down, up, down)    # red, green, blue, white
                time.sleep(DELAY)

    except KeyboardInterrupt:
        send_frame(ser, 0, 0, 0, 0)                    # switch everything off
        ser.flush()
        time.sleep(0.01)
        ser.close()
        print("stopped, all four LEDs off")


if __name__ == "__main__":
    main()

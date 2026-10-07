# ============================================================================
#  send_4_value.py  -  send ONE Flexlink frame with four brightness values
# ============================================================================
#
#  Sets red, green, blue and white to fixed levels and exits.
#  The LEDs keep that brightness until the next frame arrives.
#
#  Run:
#      python send_4_value.py                       uses the values below
#      python send_4_value.py 65535 0 0 0           full red only
#      python send_4_value.py 30000 0 10000 65535   any four values 0..65535
#
#  Needs pyserial once:  pip install pyserial
# ============================================================================

import sys
import time
import serial

PORT = "COM3"       # serial adapter port (check Device Manager if it changes)
BAUD = 115200       # must match CLKS_PER_BIT in 4_LED_top.v (115200 -> 434)

# Default levels, 0 = off, 65535 = full brightness
RED   = 65535
GREEN = 26985
BLUE  = 46260
WHITE = 0


# ----------------------------------------------------------------------------
#  How the 9th bit is made
#
#  A PC serial port only has 8 data bits, but Flexlink needs 9.
#  The parity bit sits exactly where the 9th bit would be, so we use it:
#      MARK  parity -> 9th bit = 1  (control symbols: SOP, EOP)
#      SPACE parity -> 9th bit = 0  (normal data bytes)
#
#  The parity setting must not change while bytes are still going out,
#  so we wait for the previous bytes to leave before switching.
# ----------------------------------------------------------------------------
def send_group(ser, byte_list, ninth_bit):
    ser.flush()          # wait until the PC has handed out all bytes
    time.sleep(0.002)    # small extra time for the adapter's own buffer
    ser.parity = serial.PARITY_MARK if ninth_bit else serial.PARITY_SPACE
    ser.write(bytes(byte_list))


def split16(value):
    """16-bit value -> [high byte, low byte]. Example: 30000 = 0x7530 -> [0x75, 0x30]"""
    return [value >> 8, value & 0xFF]


def send_frame(ser, red, green, blue, white):
    """[0x100]  R_hi R_lo  G_hi G_lo  B_hi B_lo  W_hi W_lo  [0x176]"""
    data = split16(red) + split16(green) + split16(blue) + split16(white)
    send_group(ser, [0x00], 1)   # 0x100  start of packet (RGBW command)
    send_group(ser, data,   0)   # 8 data bytes
    send_group(ser, [0x76], 1)   # 0x176  end of packet


def main():
    levels = [RED, GREEN, BLUE, WHITE]

    # Values from the command line replace the defaults
    if len(sys.argv) == 5:
        levels = [int(x) for x in sys.argv[1:5]]
    elif len(sys.argv) != 1:
        print("usage: python send_4_value.py [red green blue white]")
        return

    for v in levels:
        if not 0 <= v <= 65535:
            print("each value must be between 0 and 65535")
            return

    ser = serial.Serial(PORT, BAUD, bytesize=8,
                        parity=serial.PARITY_SPACE, stopbits=1)
    send_frame(ser, *levels)
    ser.flush()
    time.sleep(0.01)
    ser.close()

    print("sent  red = %d  green = %d  blue = %d  white = %d" % tuple(levels))


if __name__ == "__main__":
    main()

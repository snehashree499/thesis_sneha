# flexlink_pc.py  -  PC -> TTL adapter -> GM1 -> GM2
#   1) count segments  -> each GM gets its ID, PC gets the total
#   2) LED data        -> LEDs change, every GM answers with ID + temperature


import serial, time

PORT = "COM3"                

#        R      G      B      W        (0 .. 65535)
GM1 = [65535, 65535, 10000, 65535]      # segment 1 : hot pink
GM2 = [65535,     65535,     65535, 65535]  # segment 2 : blue + a little white

# 9th bit is made with the parity bit:  MARK = 1 (SOP/EOP),  SPACE = 0 (data)d
def send(byte_list, ninth_bit):
    ser.flush()
    time.sleep(0.002)                                   # let the previous bytes leave
    ser.parity = serial.PARITY_MARK if ninth_bit else serial.PARITY_SPACE
    ser.write(bytes(byte_list))

# PC only sees the low 8 bits:  1B0 -> B0,  180 -> 80,  176 -> 76
def show(answer):
    print("  received:", " ".join(f"{b:02X}" for b in answer) if answer else "(nothing)")

ser = serial.Serial(PORT, 1000000, bytesize=8, parity=serial.PARITY_SPACE, stopbits=1, timeout=0.5)

# ---- 1) count segments:  160 | 00 | 176  ->  answer  B0 | total | 76 ----
print("count segments ...")
ser.reset_input_buffer()
send([0x60], 1)                         # 0x160  SOP count
send([0x00], 0)                         # a = 0 segments before GM1
send([0x76], 1)                         # 0x176  EOP

answer = ser.read(64)
show(answer)
ids = []
i = 0
while i + 2 < len(answer):
    if answer[i] == 0xB0 and answer[i + 2] == 0x76:
        ids.append(answer[i + 1])
        print(f"  segment ID {answer[i + 1]:02d}")
        i += 3
    else:
        i += 1
print("  total segments:", len(ids))

# ---- 2) LED data:  100 | GM1 RGBW | GM2 RGBW | 176  ->  answers  80 | id | temp | 76 ----
print("LED data ...")
data = []
for v in GM1 + GM2:
    data += [v >> 8, v & 0xFF]          # high byte first -> 16 data bytes

ser.reset_input_buffer()
send([0x00], 1)                         # 0x100  SOP LED
send(data, 0)
send([0x76], 1)                         # 0x176  EOP
answer = ser.read(64)
show(answer)
i = 0
while i + 3 < len(answer):
    if answer[i] == 0x80 and answer[i + 3] == 0x76:
        print(f"  segment ID {answer[i + 1]} : temperature {answer[i + 2]} C")
        i += 4
    else:
        i += 1

ser.close()

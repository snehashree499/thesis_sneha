# FlexLink_Node_v1  -  PC -> GM1 -> GM2, LED data + Count Segments

One GateMate = one RGBW segment. Same bitstream on every GateMate,
the segment ID comes from Count Segments.

    Count   up : 160 | a | 176          a = segments before me, I pass on a+1, my_id = a+1
    Count   dn : 1B0 | total | 176      only the LAST GM answers
    LED     up : 100 | GM1 R G B W (8 bytes) | GM2 R G B W (8 bytes) | 176
    LED     dn : 180 | my_id | temp | 176   every GM answers after a good LED frame

Send Count first, then LED (before Count the ID is 0).
Temperature is fixed 40 C for now (MY_TEMP in flexlink_node.v).

## Wiring (PmodA, same pins on both boards)

| Pin | Signal | Dir | GM1 connects to | GM2 connects to         |
|-----|--------|-----|-----------------|-------------------------|
| 1   | up_rx  | IN  | TTL Tx          | GM1 pin 3               |
| 2   | dn_tx  | OUT | TTL Rx          | GM1 pin 4               |
| 3   | up_tx  | OUT | GM2 pin 1       | (nothing)               |
| 4   | dn_rx  | IN  | GM2 pin 2       | (nothing!  pulldown)    |
| 7   | SEG1   | OUT | red driver      | red driver              |
| 8   | SEG2   | OUT | green driver    | green driver            |
| 9   | SEG3   | OUT | blue driver     | blue driver             |
| 10  | SEG4   | OUT | white driver    | white driver            |

GND <-> GND <-> GND (TTL, GM1, GM2). NEVER connect VDD/3.3V between boards.
GM2 pin 4 must stay OPEN, that is how GM2 knows it is the last one.

On-board LEDs: D1..D4 = PWM of R G B W,  D5..D8 = my_id
(after count: GM1 -> D5 on,  GM2 -> D6 on)

## Steps
1. sim.bat                  -> simulation, expect PASS (no boards needed)
2. build.bat                -> builds once, programs GM1 (E1-32A0090) and GM2 (E1-32A0179)
3. python flexlink_pc.py    -> count + LED, expected:
       count segments ...
         received: B0 02 76
         total segments: 2
       LED data ...
         received: 80 01 28 76 80 02 28 76
         segment ID 1 : temperature 40 C
         segment ID 2 : temperature 40 C

## Files
| File                | What                                                      |
|---------------------|-----------------------------------------------------------|
| flexlink_node.v     | the whole design (+ uart_rx9, uart_tx9, fifo9 at the end) |
| flexlink_node.ccf   | pins                                                      |
| build.bat           | build + program both boards                               |
| flexlink_pc.py      | PC: count segments, then LED data, prints answers         |
| tb_flexlink_node.v  | simulation (has a fake CC_PLL inside, only for sim)       |
| sim.bat             | runs the simulation                                       |

Generated (do not commit): flexlink_node.json, flexlink_node.cfg, flexlink_node.bit, sim_node

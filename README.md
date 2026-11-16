# Design and FPGA Prototyping of a LED Driver for Aircraft Cabin Lighting with Open-Source Tools

Master's thesis of **Sneha Shree Katepalli**
Hochschule Bremen - City University of Applied Sciences

This repository holds the Verilog design of a daisy-chained RGBW LED node (Flexlink protocol) for the
Cologne Chip GateMate FPGA, the test files, the measurement data, the MATLAB/Simulink model and the
Quarto source of the thesis. The whole FPGA flow uses open-source tools only
(Yosys, nextpnr, gmpack, openFPGALoader, Icarus Verilog from the OSS CAD Suite).

## Folder structure

```
thesis_sneha/
|-- GateMate-FPGA-Projects/
|   |-- Flexlink_Node/            final design of the Flexlink node
|   |   |-- flexlink_node.v          Verilog design (top module, UART, FIFO, PWM)
|   |   |-- flexlink_node.ccf        pin constraints
|   |   |-- tb_flexlink_node.v       testbench, normal packets
|   |   |-- tb_flexlink_errors.v     testbench, error cases
|   |   |-- sim.bat / sim_errors.bat run the two simulations
|   |   |-- build.bat                synthesis, place and route, programming of both boards
|   |   |-- flexlink_pc_test.py      PC test program (pySerial, 1 MBaud, 9-bit words)
|   |   |-- flexlink_node.bit        bitstream of the final build
|   |   `-- utilisation.json         resource and timing report
|   `-- Picoscope_outputs/
|       |-- Final_outputs/           oscilloscope captures (.psdata)
|       `-- ch6_plots/               decoded CSV tables and make_ch6_plots.py
|-- matlab_model/
|   |-- simulink_model/              Simulink models
|   `-- behavioural_model/           MATLAB scripts that run the model and export the figures
|-- thesis/                          Quarto source of the thesis (content, appendix, bibliography)
|-- Documentation_Exposé/            Quarto source of the exposé
|-- files/                           datasheets and GateMate documentation
`-- workspace/                       first GateMate example projects (blink, fifo, mult)
```

## How to repeat the main steps (Windows)

The batch files expect the OSS CAD Suite in `C:\Users\<name>\eda\oss-cad-suite`.
Change the path `YOSYSHQ_ROOT` at the top of each `.bat` file if it is installed somewhere else.

1. **Simulation** (no boards needed). In `GateMate-FPGA-Projects/Flexlink_Node` run `sim.bat` and
   `sim_errors.bat`. Both end with `PASS`.
2. **Build and programming.** Connect both GateMate evaluation boards by USB and run `build.bat`.
   The same bitstream is loaded into both boards. They are selected by their USB serial number.
3. **Hardware test.** Wire the boards as described in `Flexlink_Node/README.md` and run
   `python flexlink_pc_test.py`.
4. **Plots of Chapter 6.** Run `python make_ch6_plots.py` in `Picoscope_outputs/ch6_plots`.
5. **Simulink model.** Open MATLAB R2025b in `matlab_model/behavioural_model` and run
   `run_singlewire_txrx_rgbw.m`.
6. **Thesis PDF.** Run `quarto render --to pdf` in the folder `thesis`.

## Hardware

- 2 x Cologne Chip GateMate FPGA Evaluation Board (CCGM1A1, version 3.2A)
- CP2104 USB-to-TTL adapter (PC as Flexlink master)
- BS170 MOSFETs and 5 mm red, green, blue and white LEDs on a breadboard
- PicoScope 4444 for the measurements

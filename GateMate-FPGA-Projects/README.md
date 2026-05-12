# GateMate FPGA Learning Projects

## Overview

This repository contains my basic FPGA learning projects using the GateMate FPGA Evaluation Board.

The purpose of these projects is to understand the basic FPGA design flow using Verilog and open-source tools.

I used Antigravity AI Agent to help me generate the Verilog logic, create the project files, debug errors and understand the code.

## Tools Used

- GateMate FPGA Evaluation Board
- Verilog HDL
- OSS CAD Suite
- Yosys
- nextpnr-himbaechel
- gmpack
- openFPGALoader
- Zadig USB driver tool
- Antigravity AI Agent
- Git and GitHub

## Use of Antigravity AI Agent

I used Antigravity AI Agent as a learning and development assistant.

Antigravity helped me in the following ways:

- Created basic Verilog logic for the projects
- Created `.ccf` constraint files
- Created `build.bat` files
- Helped with OSS CAD Suite commands
- Helped debug build and flashing errors
- Helped solve the USB driver issue using Zadig
- Explained the Verilog code in simple words
- Helped prepare walkthrough and README documentation

After Antigravity generated the logic and files, I tested the designs on the GateMate FPGA board.
I checked the LED output, asked for explanations, understood the code, and made changes step by step.
Using Antigravity helped me learn faster because I could ask questions immediately when I did not understand something.
It also helped me understand the FPGA workflow from Verilog code to physical hardware output.

## Basic FPGA Flow Followed

The same basic flow was followed for all projects:

1. Create project folder
2. Add Verilog file
3. Add `.ccf` pin constraint file
4. Add build script
5. Run synthesis using Yosys
6. Run place-and-route using nextpnr
7. Pack the bitstream using gmpack
8. Upload to FPGA using openFPGALoader
9. Test the output on the physical board

## Repository Structure

```text
GateMate-FPGA-Learning-Projects/
│
├── README.md
│
├── 01_LED_Blink/
├── 02_Button_Controlled_LED/
├── 03_Knight_Rider_Running_Light/
├── 04_PWM_Brightness_Control/
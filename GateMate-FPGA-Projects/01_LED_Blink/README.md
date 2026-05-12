# LED Blink Project

## Overview

This is the first basic FPGA project on the GateMate FPGA board.

In this project, Antigravity helped me create Verilog logic to blink one LED using a counter.

## Files

- `blink.v` - Verilog code
- `blink.ccf` - Pin constraint file
- `build.bat` - Build and programming script

## How It Works

The FPGA clock is very fast, so the LED cannot be connected directly to the clock.

A counter is used to slow down the signal.  
One bit of the counter is connected to the LED output.  
Because this bit changes slowly, the LED turns ON and OFF at a visible speed.

## What I Learned

- Basic Verilog module structure
- Clock usage
- Counter logic
- LED output control
- FPGA pin mapping
- Basic OSS CAD Suite build flow
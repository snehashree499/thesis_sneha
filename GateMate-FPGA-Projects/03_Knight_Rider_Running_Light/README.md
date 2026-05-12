# Knight Rider Running Light Project

## Overview

This project creates a running LED effect using 8 LEDs on the GateMate FPGA board.

Antigravity helped me create the shift register and direction logic.

## Files

- `knight_rider.v` - Verilog code
- `knight_rider.ccf` - Pin constraint file
- `build.bat` - Build and programming script

## How It Works

Only one LED is ON at a time.

The ON LED moves from one side to the other side.  
When it reaches the last LED, the direction changes and the light moves back.

A counter is used to slow down the movement so that the human eye can see the running effect.

## What I Learned

- How to control 8 LEDs
- How shift registers work
- How to shift bits left and right
- How to use direction logic
- Why a delay counter is needed
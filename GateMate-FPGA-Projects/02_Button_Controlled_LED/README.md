# Button-Controlled LED Project

## Overview

This project uses a push button to control an LED on the GateMate FPGA board.

Antigravity helped me create the button input logic and debounce logic.

## Files

- `button.v` - Verilog code
- `button.ccf` - Pin constraint file
- `build.bat` - Build and programming script

## How It Works

When the button is pressed, the LED changes its state.

A debounce counter is used because a mechanical button does not give a clean signal immediately.  
The signal may bounce between ON and OFF for a short time.

The debounce logic waits until the button signal is stable before changing the LED state.

## What I Learned

- How to use push button input
- How to control LED output
- What button bouncing means
- Why debounce is required
- How to detect a clean button press
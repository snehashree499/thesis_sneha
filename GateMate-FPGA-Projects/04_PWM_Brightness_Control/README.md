# PWM Brightness Control Project

## Overview

This project controls the brightness of 8 LEDs using PWM.

Antigravity helped me create the PWM logic and timer-based brightness control.

## Files

- `pwm.v` - Verilog code
- `pwm.ccf` - Pin constraint file
- `build.bat` - Build and programming script

## How It Works

The brightness was divided into 8 levels.  
A timer changes the brightness automatically.

## What I Learned

- What PWM means
- How duty cycle controls brightness
- How to create different brightness levels
- How to use timer-based control
- How to apply PWM to all 8 LEDs
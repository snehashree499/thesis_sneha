@echo off
REM ==========================================================================
REM  build_4.bat  -  synthesise, place and route 4_LED_top.v, then program it
REM ==========================================================================
REM
REM  Usage:
REM      build_4.bat                 programs board E1-32A0090
REM      build_4.bat E1-32A0179      programs the other board
REM
REM  Steps:
REM      1. yosys     Verilog  -> netlist        (4_LED.json)
REM      2. nextpnr   netlist  -> placed design  (4_LED.cfg)
REM      3. gmpack    design   -> bitstream      (4_LED.bit)
REM      4. openFPGALoader     -> loads the bitstream into the FPGA
REM ==========================================================================

set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"

set "BOARD=E1-32A0090"
if not "%~1"=="" set "BOARD=%~1"

echo ==========================================================
echo   Flexlink 4-channel LED receiver  -  board %BOARD%
echo ==========================================================
echo.

echo [1/4] Synthesis ...
yosys -q -p "read_verilog 4_LED_top.v uart_rx9.v; synth_gatemate -top four_led_top -nomx8 -luttree; write_json 4_LED.json"
if errorlevel 1 goto :fail

echo [2/4] Place and route ...
nextpnr-himbaechel --device CCGM1A1 --json 4_LED.json --vopt ccf=4_LED.ccf --vopt out=4_LED.cfg
if errorlevel 1 goto :fail

echo [3/4] Bitstream ...
gmpack 4_LED.cfg 4_LED.bit
if errorlevel 1 goto :fail

echo [4/4] Programming %BOARD% ...
openFPGALoader -b gatemate_evb_jtag --usb-serial-num %BOARD% 4_LED.bit
if errorlevel 1 goto :fail

echo.
echo Done. Now run one of:
echo     python send_4_value.py
echo     python send_4_fade.py
goto :eof

:fail
echo.
echo *** BUILD FAILED - see the last error message above. ***
exit /b 1

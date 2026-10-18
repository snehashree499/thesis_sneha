@echo off
REM ---------------------------------------------------------------------
REM  Build ONCE, program BOTH GateMates with the same bitstream.
REM  Both boards stay plugged in (picked by serial number).
REM
REM     build.bat                         <- GM1 = E1-32A0090, GM2 = E1-32A0179
REM     build.bat E1-32A0179 E1-32A0090   <- other order
REM ---------------------------------------------------------------------
set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"
cd /d "%~dp0"

set "GM1=E1-32A0090"
set "GM2=E1-32A0179"
if not "%~1"=="" set "GM1=%~1"
if not "%~2"=="" set "GM2=%~2"

echo =================================================
echo  flexlink_node - same bitstream for GM1 and GM2
echo  GM1 = %GM1%     GM2 = %GM2%
echo =================================================

yosys -q -p "read_verilog flexlink_node.v; synth_gatemate -top flexlink_node -nomx8 -luttree; write_json flexlink_node.json"
if errorlevel 1 goto :fail

nextpnr-himbaechel --device CCGM1A1 --json flexlink_node.json --vopt ccf=flexlink_node.ccf --vopt out=flexlink_node.cfg
if errorlevel 1 goto :fail

gmpack flexlink_node.cfg flexlink_node.bit
if errorlevel 1 goto :fail

echo.
echo Programming GM1 (%GM1%) ...
openFPGALoader -b gatemate_evb_jtag --usb-serial-num %GM1% flexlink_node.bit
if errorlevel 1 goto :fail

echo.
echo Programming GM2 (%GM2%) ...
openFPGALoader -b gatemate_evb_jtag --usb-serial-num %GM2% flexlink_node.bit
if errorlevel 1 goto :fail

echo.
echo Both done. Now:  python flexlink_pc.py
goto :eof

:fail
echo.
echo *** BUILD FAILED - read the last error message above. ***

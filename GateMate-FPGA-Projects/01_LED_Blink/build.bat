@echo off
set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"

echo Running Yosys to synthesize...
yosys -p "read_verilog blink.v; synth_gatemate -top top -nomx8; write_json blink.json"

echo.
echo Running nextpnr to place and route...
nextpnr-himbaechel --device CCGM1A1 --vopt ccf=blink.ccf --vopt out=blink.cfg --json blink.json

echo.
echo Running gmpack to generate bitstream...
gmpack blink.cfg blink.bit

echo.
echo Build complete!
echo If your FPGA is connected, programming it now...
openFPGALoader -b gatemate_evb_jtag blink.bit

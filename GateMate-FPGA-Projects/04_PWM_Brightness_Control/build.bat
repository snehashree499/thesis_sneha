@echo off
set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"

echo Running Yosys to synthesize...
yosys -p "read_verilog pwm.v; synth_gatemate -top top -nomx8 -luttree; write_json pwm.json"

echo.
echo Running nextpnr to place and route...
nextpnr-himbaechel --device CCGM1A1 --vopt ccf=pwm.ccf --vopt out=pwm.cfg --json pwm.json

echo.
echo Running gmpack to generate bitstream...
gmpack pwm.cfg pwm.bit

echo.
echo Build complete!
echo Programming FPGA...
openFPGALoader -b gatemate_evb_jtag pwm.bit

@echo off
REM ---------------------------------------------------------------------
REM  Simulation, no boards needed. Takes ~30 s. Expect "PASS" at the end.
REM ---------------------------------------------------------------------
set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"
cd /d "%~dp0"
iverilog -g2005 -o sim_node tb_flexlink_node.v flexlink_node.v
if errorlevel 1 goto :eof
vvp sim_node

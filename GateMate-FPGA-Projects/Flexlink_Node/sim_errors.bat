@echo off
REM ---------------------------------------------------------------------
REM  Error-case simulation, no boards needed. Expect "PASS" at the end.
REM ---------------------------------------------------------------------
set "YOSYSHQ_ROOT=C:\Users\Sneha Shree K\eda\oss-cad-suite\"
call "%YOSYSHQ_ROOT%environment.bat"
cd /d "%~dp0"
iverilog -g2005 -o sim_errors tb_flexlink_errors.v flexlink_node.v
if errorlevel 1 goto :eof
vvp sim_errors

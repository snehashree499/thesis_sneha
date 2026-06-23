clc;
clear;
close all;

% -----------------------------------------
% STEP 4: GateMate FPGA serial data model
% -----------------------------------------

% Example: 16 brightness values
brightness = uint16([
    65535
    0
    32768
    10000
    20000
    30000
    40000
    50000
    60000
    1000
    2000
    3000
    4000
    5000
    6000
    7000
]);

% AL58263Q sends MSB first
serial_bits = [];

for ch = 16:-1:1
    value = brightness(ch);
    
    % Convert 16-bit number to binary string
    bin_string = dec2bin(value, 16);
    
    % Convert characters '0'/'1' into numbers 0/1
    bits = bin_string - '0';
    
    % Append to serial stream
    serial_bits = [serial_bits bits];
end

disp(serial_bits)

% Create simple DCK signal
num_bits = length(serial_bits);
DCK = repmat([0 1], 1, num_bits);

% DI changes once per bit
DI = repelem(serial_bits, 2);
x = length(DI);
disp(x)

% LAT pulse after data transfer
LAT = zeros(1, length(DI));
LAT(end-5:end) = 1;

% Plot first 80 samples
samples = 1:80;

figure;
stairs(samples, DCK(samples), 'LineWidth', 1.5);
grid on;
ylim([-0.2 1.2]);
xlabel('Sample');
ylabel('DCK');
title('GateMate Generated DCK');

figure;
stairs(samples, DI(samples), 'LineWidth', 1.5);
grid on;
ylim([-0.2 1.2]);
xlabel('Sample');
ylabel('DI');
title('GateMate Generated DI');

figure;
stairs(1:length(LAT), LAT, 'LineWidth', 1.5);
grid on;
ylim([-0.2 1.2]);
xlabel('Sample');
ylabel('LAT');
title('Latch Signal After Data Transfer');
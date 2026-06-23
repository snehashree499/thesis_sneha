clc;
clear;
close all;

% -----------------------------------------
% STEP 2: 16-channel AL58263Q simulation
% -----------------------------------------

N = 65536;

% Maximum current per channel
Imax = 20e-3;   % 20 mA

% 16 brightness values for OUT0 to OUT15
brightness = [
    0
    5000
    10000
    15000
    20000
    25000
    30000
    32768
    40000
    45000
    50000
    55000
    60000
    62000
    64000
    65535
];

counter = 0:N-1;

led_current = zeros(16, N);
%average_current = zeros(16, 1);
average_current = Imax * (brightness / N);

for ch = 1:16
    pwm_output = counter < brightness(ch);
    led_current(ch, :) = Imax * pwm_output;
    average_current(ch) = mean(led_current(ch, :));
end

% Display average current of each channel
disp('Channel   Brightness   Average Current (mA)');
for ch = 1:16
    fprintf('OUT%-2d     %-6d       %.3f\n', ...
        ch-1, brightness(ch), average_current(ch)*1000);
end

% Plot average current
figure;
bar(0:15, average_current * 1000);
grid on;
xlabel('AL58263Q Output Channel');
ylabel('Average Current (mA)');
title('Average Current of 16 AL58263Q Channels');
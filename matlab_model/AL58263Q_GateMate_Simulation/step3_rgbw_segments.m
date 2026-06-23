clc;
clear;
close all;

% -----------------------------------------
% STEP 3: RGBW segment mapping
% -----------------------------------------

Imax = 20e-3;
MAX_16BIT = 65535;

% Four RGBW segments
% Columns: R, G, B, W
rgbw = [
    65535  0      0      10000   % Segment 1: Red
    0      65535  0      10000   % Segment 2: Green
    0      0      65535  10000   % Segment 3: Blue
    20000  20000  20000  65535   % Segment 4: White
];

% Convert 4x4 matrix into 16 AL58263Q channel values
brightness = reshape(rgbw.', 16, 1);

average_current = Imax * brightness / MAX_16BIT;

disp('AL58263Q Channel Mapping');
disp('OUT0=Seg1_R, OUT1=Seg1_G, OUT2=Seg1_B, OUT3=Seg1_W, etc.');

for ch = 1:16
    fprintf('OUT%-2d brightness = %-6d, avg current = %.3f mA\n', ...
        ch-1, brightness(ch), average_current(ch)*1000);
end

figure;
bar(0:15, average_current * 1000);
grid on;
xlabel('AL58263Q Output Channel');
ylabel('Average Current (mA)');
title('RGBW Segment Current Mapping');
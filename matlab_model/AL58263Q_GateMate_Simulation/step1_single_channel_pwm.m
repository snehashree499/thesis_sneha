clc;
clear;
close all;

% -----------------------------------------
% STEP 1: Single channel AL58263Q simulation
% -----------------------------------------

% AL58263Q has 16-bit brightness control
MAX_16BIT = 65535;
pwm_percentage = 80; % Sent by gateMate
% Choose one brightness value
brightness_value = MAX_16BIT * (pwm_percentage/100);   % 50% brightness approximately

% Choose LED channel current
Imax = 20e-3;               % 20 mA maximum current

% Number of PWM counter steps
N = 65536;

% Create PWM counter
counter = 0:N-1;

% PWM output: ON when counter is below brightness value
pwm_output = counter < brightness_value;

% LED current waveform
led_current = Imax * pwm_output;

% Average current
average_current = mean(led_current);

% Display result
fprintf('Brightness value = %d out of 65535\n', brightness_value);
fprintf('Average LED current = %.3f mA\n', average_current * 1000);

% Plot PWM current
figure;
plot(counter(1:1000), led_current(1:1000) * 1000, 'LineWidth', 1.5);
grid on;
xlabel('PWM counter');
ylabel('LED current (mA)');
title('Single LED Channel PWM Current');
clc;
clear;
close all;

%% 16-bit PWM frequency model

pwm_resolution = 16;
counter_max = 2^pwm_resolution;

clock_frequencies = [10e6, 25e6, 27e6, 50e6, 100e6];

fprintf('Clock Frequency [MHz]    PWM Frequency [Hz]\n');

for i = 1:length(clock_frequencies)
    f_clk = clock_frequencies(i);
    f_pwm = f_clk / counter_max;
    fprintf('%10.2f              %10.2f\n', f_clk/1e6, f_pwm);
end

%% Plot PWM frequency vs clock frequency

clock_range = linspace(1e6, 100e6, 1000);
pwm_frequency = clock_range / counter_max;

figure;
plot(clock_range/1e6, pwm_frequency, 'LineWidth', 2);
grid on;
xlabel('FPGA Clock Frequency [MHz]');
ylabel('PWM Frequency [Hz]');
title('16-bit PWM Frequency vs FPGA Clock Frequency');
yline(400, '--', '400 Hz Requirement');
%% PWM waveform simulation

f_clk = 50e6;                 % 50 MHz FPGA clock
pwm_bits = 16;
counter_period = 2^pwm_bits;

% Select duty cycle
duty_percent = 25;
duty_value = round((duty_percent/100) * counter_period);

% Simulate one PWM period
counter = 0:counter_period-1;
pwm_out = counter < duty_value;

% Plot only first part for visibility
%samples_to_plot = 5000;
samples_to_plot = counter_period;

figure;
stairs(counter(1:samples_to_plot), pwm_out(1:samples_to_plot), 'LineWidth', 2);
grid on;
xlabel('Clock Cycles');
ylabel('PWM Output');
title(['16-bit PWM Output, Duty Cycle = ', num2str(duty_percent), '%']);
ylim([-0.2 1.2]);

fprintf('\nPWM duty simulation:\n');
fprintf('Duty percent: %.2f %%\n', duty_percent);
fprintf('Duty register value: %d\n', duty_value);
fprintf('PWM frequency at %.2f MHz clock: %.2f Hz\n', f_clk/1e6, f_clk/counter_period);
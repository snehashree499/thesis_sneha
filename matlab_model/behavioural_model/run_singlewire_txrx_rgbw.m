clear;
close all;

%% ============================================================
%  MASTER RUN SCRIPT
%  RGBW serial input -> Digital PWM -> Simscape RGBW LED currents
%  ============================================================

%% Simulink model name

modelName = "GateMate_SingleWire_TxRx_RGBW";

%% Test brightness values

R_Value = uint16(10000);
G_Value = uint16(20000);
B_Value = uint16(30000);
W_Value = uint16(40000);

BITS_PER_CHANNEL = 16;
FRAME_BITS = 64;
MAX_COUNT = 2^BITS_PER_CHANNEL;

fprintf('\nRGBW test values\n');
fprintf('R = %5d\n', R_Value);
fprintf('G = %5d\n', G_Value);
fprintf('B = %5d\n', B_Value);
fprintf('W = %5d\n', W_Value);

%% Expected PWM duty cycles

R_duty = double(R_Value) / MAX_COUNT * 100;
G_duty = double(G_Value) / MAX_COUNT * 100;
B_duty = double(B_Value) / MAX_COUNT * 100;
W_duty = double(W_Value) / MAX_COUNT * 100;

fprintf('\nExpected PWM duty cycles\n');
fprintf('PWM_R = %.2f %%\n', R_duty);
fprintf('PWM_G = %.2f %%\n', G_duty);
fprintf('PWM_B = %.2f %%\n', B_duty);
fprintf('PWM_W = %.2f %%\n', W_duty);

%% 64-bit reference frame
% Frame mapping:
% bits [63:48] = R
% bits [47:32] = G
% bits [31:16] = B
% bits [15:0]  = W

frame64 = ...
    bitor( ...
        bitshift(uint64(R_Value), 48), ...
        bitor( ...
            bitshift(uint64(G_Value), 32), ...
            bitor( ...
                bitshift(uint64(B_Value), 16), ...
                uint64(W_Value))));

fprintf('\nExpected 64-bit frame\n');
fprintf('Hexadecimal frame = 0x%s\n', dec2hex(frame64, 16));

%% Generate 64-bit serial data
% Transmission order: R -> G -> B -> W
% Bit order: MSB first

R_bits = double(bitget(R_Value, BITS_PER_CHANNEL:-1:1));
G_bits = double(bitget(G_Value, BITS_PER_CHANNEL:-1:1));
B_bits = double(bitget(B_Value, BITS_PER_CHANNEL:-1:1));
W_bits = double(bitget(W_Value, BITS_PER_CHANNEL:-1:1));

serial_bits = [R_bits G_bits B_bits W_bits];

fprintf('\nSerial data\n');
fprintf('Total number of bits = %d\n', length(serial_bits));

%% Communication timing
% This is slow timing for simulation visibility.
% It is not the final hardware speed.

Tbit = 1e-3;                  % 1 ms per bit
samples_per_bit = 4;
Ts = Tbit / samples_per_bit;

frame_time = FRAME_BITS * Tbit;
simStopTime = 0.22;

time = (0:Ts:simStopTime).';
number_of_samples = length(time);

%% Single-wire serial communication signal
% This signal represents a simple one-wire Tx/Rx communication line.
% The line stays HIGH when idle.
% A LOW start bit tells the receiver that a new frame is beginning.
%
% Frame format:
% Idle bits -> Start bit -> 64 data bits -> Stop bit -> Idle bits
%
% Data order:
% R -> G -> B -> W, MSB first

IDLE_LEVEL = 1;
START_BIT  = 0;
STOP_BIT   = 1;

PRE_IDLE_BITS  = 5;     % idle time before transmission starts
POST_IDLE_BITS = 10;    % idle time after transmission ends

singlewire_bits = [ ...
    ones(1, PRE_IDLE_BITS) * IDLE_LEVEL, ...
    START_BIT, ...
    serial_bits, ...
    STOP_BIT, ...
    ones(1, POST_IDLE_BITS) * IDLE_LEVEL ...
];

SINGLEWIRE_TOTAL_BITS = length(singlewire_bits);
singlewire_frame_time = SINGLEWIRE_TOTAL_BITS * Tbit;

fprintf('\nSingle-wire communication frame\n');
fprintf('Pre-idle bits       = %d\n', PRE_IDLE_BITS);
fprintf('Start bit           = %d\n', START_BIT);
fprintf('Data bits           = %d\n', FRAME_BITS);
fprintf('Stop bit            = %d\n', STOP_BIT);
fprintf('Post-idle bits      = %d\n', POST_IDLE_BITS);
fprintf('Total transmitted bits = %d\n', SINGLEWIRE_TOTAL_BITS);
fprintf('Single-wire frame time = %.3f ms\n', singlewire_frame_time*1000);

%% Create single-wire timeseries signal

Serial_Data_data = ones(number_of_samples, 1) * IDLE_LEVEL;

singlewire_samples = repelem(singlewire_bits, samples_per_bit);

Serial_Data_data(1:length(singlewire_samples)) = singlewire_samples(:);

Serial_Data_sim = timeseries(Serial_Data_data, time);

fprintf('\nSingle-wire Simulink input signal created\n');
fprintf('Serial data variable = Serial_Data_sim\n');

%% Generate Data_In signal

Data_In_data = zeros(number_of_samples, 1);

serial_samples = repelem(serial_bits, samples_per_bit);
Data_In_data(1:length(serial_samples)) = serial_samples(:);

%% Generate LE_In signal

LE_In_data = zeros(number_of_samples, 1);

LE_start = frame_time - Ts;
LE_stop  = frame_time + Ts;

LE_In_data(time >= LE_start & time <= LE_stop) = 1;

%% Create Simulink timeseries inputs
% These are used by the From Workspace blocks in Simulink.

Data_In_sim = timeseries(Data_In_data, time);
LE_In_sim   = timeseries(LE_In_data, time);

fprintf('\nSimulink input signals created\n');
fprintf('Data variable = Data_In_sim\n');
fprintf('LE variable   = LE_In_sim\n');
fprintf('Bit time = %.3f ms\n', Tbit*1000);
fprintf('Frame transmission time = %.3f ms\n', frame_time*1000);
fprintf('LE window = %.3f ms to %.3f ms\n', LE_start*1000, LE_stop*1000);
fprintf('Simulation stop time = %.3f s\n', simStopTime);

%% MATLAB serialization check

reconstructed_frame = uint64(0);

for k = 1:FRAME_BITS
    reconstructed_frame = bitshift(reconstructed_frame, 1);
    reconstructed_frame = bitor(reconstructed_frame, uint64(serial_bits(k)));
end

fprintf('\nMATLAB serialization check\n');
fprintf('Original      = 0x%s\n', dec2hex(frame64, 16));
fprintf('Reconstructed = 0x%s\n', dec2hex(reconstructed_frame, 16));

assert(reconstructed_frame == frame64, ...
    'MATLAB serialization check failed.');

disp('MATLAB serialization check passed.');

%% Run Simulink model automatically

fprintf('\nOpening and running Simulink model...\n');

load_system(modelName);

% Set the Stop Time automatically from MATLAB
set_param(modelName, 'StopTime', 'simStopTime');

% Run simulation and store result in variable "out"
out = sim(modelName);

disp('Simulink simulation completed.');

%% Check LED current results

I_R_min = min(out.I_LED_R_ts.Data);
I_G_min = min(out.I_LED_G_ts.Data);
I_B_min = min(out.I_LED_B_ts.Data);
I_W_min = min(out.I_LED_W_ts.Data);

I_R_max = max(out.I_LED_R_ts.Data);
I_G_max = max(out.I_LED_G_ts.Data);
I_B_max = max(out.I_LED_B_ts.Data);
I_W_max = max(out.I_LED_W_ts.Data);

fprintf('\nLED current check\n');
fprintf('Minimum currents\n');
fprintf('I_LED_R min = %.4e A\n', I_R_min);
fprintf('I_LED_G min = %.4e A\n', I_G_min);
fprintf('I_LED_B min = %.4e A\n', I_B_min);
fprintf('I_LED_W min = %.4e A\n', I_W_min);

fprintf('\nMaximum currents\n');
fprintf('I_LED_R max = %.4f A\n', I_R_max);
fprintf('I_LED_G max = %.4f A\n', I_G_max);
fprintf('I_LED_B max = %.4f A\n', I_B_max);
fprintf('I_LED_W max = %.4f A\n', I_W_max);

%% Plot input serial data and latch signal

figure;

subplot(2,1,1);
stairs(time*1000, Data_In_data, 'LineWidth', 1.1);
grid on;
ylabel('Data In');
title('Generated 64-bit RGBW Serial Data');
xlim([0 70]);
ylim([-0.1 1.2]);

subplot(2,1,2);
stairs(time*1000, LE_In_data, 'LineWidth', 1.3);
grid on;
xlabel('Time (ms)');
ylabel('LE');
title('Generated Latch Enable Signal');
xlim([60 68]);
ylim([-0.1 1.2]);

%% Plot all four LED currents

figure;

plot(out.I_LED_R_ts.Time, out.I_LED_R_ts.Data * 1000, 'LineWidth', 1.2);
hold on;
plot(out.I_LED_G_ts.Time, out.I_LED_G_ts.Data * 1000, 'LineWidth', 1.2);
plot(out.I_LED_B_ts.Time, out.I_LED_B_ts.Data * 1000, 'LineWidth', 1.2);
plot(out.I_LED_W_ts.Time, out.I_LED_W_ts.Data * 1000, 'LineWidth', 1.2);

grid on;
xlabel('Time (s)');
ylabel('LED current (mA)');
title('Simscape RGBW LED Currents');

legend('I_{LED,R}', 'I_{LED,G}', 'I_{LED,B}', 'I_{LED,W}', ...
       'Location', 'best');

xlim([0.06 0.22]);
ylim([-1 25]);

%% Plot single-wire serial communication signal with start and stop bit markers

figure;

stairs(time*1000, Serial_Data_data, 'LineWidth', 1.2);
grid on;
xlabel('Time (ms)');
ylabel('SERIAL\_DATA');
title('Single-Wire Serial Communication Signal with Start and Stop Bit');

xlim([0 85]);
ylim([-0.2 1.2]);

% Important timing markers
start_bit_begin_ms = PRE_IDLE_BITS * Tbit * 1000;
start_bit_end_ms   = (PRE_IDLE_BITS + 1) * Tbit * 1000;

data_begin_ms = start_bit_end_ms;
data_end_ms   = (PRE_IDLE_BITS + 1 + FRAME_BITS) * Tbit * 1000;

stop_bit_begin_ms = data_end_ms;
stop_bit_end_ms   = stop_bit_begin_ms + Tbit * 1000;

xline(start_bit_begin_ms, '--', 'Start bit begins');
xline(start_bit_end_ms,   '--', 'Start bit ends');

xline(stop_bit_begin_ms, '--', 'Stop bit begins');
xline(stop_bit_end_ms,   '--', 'Stop bit ends');

text(start_bit_begin_ms + 0.2, 0.15, 'START BIT = 0');
text(stop_bit_begin_ms + 0.2, 0.85, 'STOP BIT = 1');

%% Final message

fprintf('\nFinal result\n');
disp('One-run MATLAB + Simulink + Simscape simulation completed successfully.');
disp('Expected result: min currents near 0 A and max currents near 0.022 A.');


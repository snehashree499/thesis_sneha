clear;
close all;

%% ============================================================
%  SYSTEM-LEVEL MODEL - RUN SCRIPT
%
%  What this model covers
%    A two-node single-wire link. A 64-bit RGBW frame is serialised
%    in MATLAB, received by node 1, passed on to node 2, decoded
%    into four 16-bit channels, turned into four PWM signals and
%    applied to a Simscape LED power stage. Both nodes log their
%    LED currents.
%
%  What this model does NOT cover
%    This is not the Flexlink protocol. The model was built before
%    the Flexlink specification was available in full. The main
%    differences, listed in full in Chapter 4:
%      - one 64-bit frame, MSB first, instead of eight 11-bit words
%        with 9 data bits LSB first
%      - 1 ms per bit instead of 1 MBd (11 us per word)
%      - no 9th control bit, no node ID, no answer words
%      - repeater forwarding: node 1 passes the whole frame on,
%        while the implemented node keeps 8 bytes and forwards the
%        rest (cut-through)
%
%  Time base
%    The model runs 1000 times slower than the hardware: 1 ms per
%    bit here against 1 us per bit on the line. This is only so that
%    one PWM period stays visible next to one bit period.
%  ============================================================

%% Project paths
% Makes the model and the block library findable wherever the
% project folder sits, so the script also runs on another machine.

thisFile    = mfilename('fullpath');
projectRoot = fileparts(fileparts(thisFile));      % up from behavioural_model

if isfolder(fullfile(projectRoot,'libraries'))
    addpath(fullfile(projectRoot,'libraries'));
end
if isfolder(fullfile(projectRoot,'simulink_model'))
    addpath(fullfile(projectRoot,'simulink_model'));
end

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

%% [NEW] Channel colours, used in every figure
% White cannot be shown on a white page, so W is drawn in dark grey.
% The LED current traces also get different line styles, so the
% figure stays readable when the thesis is printed in greyscale.

COL_R = [0.80 0.00 0.00];
COL_G = [0.00 0.55 0.15];
COL_B = [0.00 0.30 0.80];
COL_W = [0.35 0.35 0.35];

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
%
% note: the implemented Flexlink receiver takes 9-bit words
% LSB first, with the high byte of each channel sent first. The bit
% order here is a property of this model only (see Chapter 4).

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

%% Forwarding delay, scaled to the model time base
% Measured on hardware: mean 10.69 us over 96 forwarded words.
% The model runs 1000 times slower, so the same delay becomes
% 10.69 ms here.
%
% This variable is used by the Transport Delay block inside
% SingleWire_RX (Serial_In -> Transport Delay -> Serial_Out).
% If that block is not present, the variable is simply unused and
% node 2 receives the frame at the same instant as node 1.

TIME_SCALE      = Tbit / 1e-6;                  % = 1000
fwd_delay_hw    = 10.69e-6;                     % s, measured
fwd_delay_model = fwd_delay_hw * TIME_SCALE;    % s, in model time

fprintf('\nForwarding delay\n');
fprintf('Hardware (measured) = %.2f us\n', fwd_delay_hw*1e6);
fprintf('Model (scaled by %d) = %.2f ms\n', TIME_SCALE, fwd_delay_model*1000);

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


%% Timing summary for the present model

fprintf('\nTiming\n');
fprintf('Bit time = %.3f ms\n', Tbit*1000);
fprintf('Samples per bit = %d (Ts = %.3f ms)\n', samples_per_bit, Ts*1000);
fprintf('Frame transmission time = %.3f ms\n', frame_time*1000);
fprintf('Simulation stop time = %.3f s\n', simStopTime);

%% MATLAB serialization check
% This checks only that the MATLAB side packed and unpacked the
% frame consistently. It says nothing about the receiver in the
% model. See the optional receiver check further down.

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

%% Is node 2 logged in this model?

try
    test_node2 = out.I_LED_R_ts1;    %#ok<NASGU>
    hasNode2 = true;
catch
    hasNode2 = false;
end


%% LED current check, both nodes

fprintf('\nLED current check\n');
fprintf('%-8s %-3s %14s %12s\n', 'Node', 'Ch', 'min [A]', 'max [A]');

fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 1', 'R', ...
        min(out.I_LED_R_ts.Data), max(out.I_LED_R_ts.Data));
fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 1', 'G', ...
        min(out.I_LED_G_ts.Data), max(out.I_LED_G_ts.Data));
fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 1', 'B', ...
        min(out.I_LED_B_ts.Data), max(out.I_LED_B_ts.Data));
fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 1', 'W', ...
        min(out.I_LED_W_ts.Data), max(out.I_LED_W_ts.Data));

if hasNode2
    fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 2', 'R', ...
            min(out.I_LED_R_ts1.Data), max(out.I_LED_R_ts1.Data));
    fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 2', 'G', ...
            min(out.I_LED_G_ts1.Data), max(out.I_LED_G_ts1.Data));
    fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 2', 'B', ...
            min(out.I_LED_B_ts1.Data), max(out.I_LED_B_ts1.Data));
    fprintf('%-8s %-3s %14.3e %12.4f\n', 'Node 2', 'W', ...
            min(out.I_LED_W_ts1.Data), max(out.I_LED_W_ts1.Data));
else
    fprintf('Node 2 outputs not found in this model.\n');
end

%% Node comparison
% In this model node 1 forwards the complete frame, so node 2 must
% reach the same currents. In the implemented design node 1 keeps
% the first 8 data bytes and forwards the rest, so the two nodes
% show different colours there (Chapter 4, model vs implementation).

if hasNode2
    fprintf('\nNode comparison (repeater forwarding)\n');
    fprintf('R max: node 1 = %.4f A, node 2 = %.4f A\n', ...
            max(out.I_LED_R_ts.Data), max(out.I_LED_R_ts1.Data));
    fprintf('G max: node 1 = %.4f A, node 2 = %.4f A\n', ...
            max(out.I_LED_G_ts.Data), max(out.I_LED_G_ts1.Data));
    fprintf('B max: node 1 = %.4f A, node 2 = %.4f A\n', ...
            max(out.I_LED_B_ts.Data), max(out.I_LED_B_ts1.Data));
    fprintf('W max: node 1 = %.4f A, node 2 = %.4f A\n', ...
            max(out.I_LED_W_ts.Data), max(out.I_LED_W_ts1.Data));
end


%% Plot LED currents for both nodes

figure;

subplot(2,1,1);

% channel colours and line styles
plot(out.I_LED_R_ts.Time*1000, out.I_LED_R_ts.Data*1000, '-',  'Color', COL_R, 'LineWidth', 1.3);
hold on;
plot(out.I_LED_G_ts.Time*1000, out.I_LED_G_ts.Data*1000, '--', 'Color', COL_G, 'LineWidth', 1.3);
plot(out.I_LED_B_ts.Time*1000, out.I_LED_B_ts.Data*1000, '-.', 'Color', COL_B, 'LineWidth', 1.3);
plot(out.I_LED_W_ts.Time*1000, out.I_LED_W_ts.Data*1000, ':',  'Color', COL_W, 'LineWidth', 1.6);
grid on;
ylabel('LED current [mA]');
title('Node 1: Simscape RGBW LED currents');
legend('I_{LED,R}','I_{LED,G}','I_{LED,B}','I_{LED,W}', ...
       'Location','eastoutside');
xlim([60 simStopTime*1000]);
ylim([-1 25]);

subplot(2,1,2);
if hasNode2

    % channel colours and line styles
    plot(out.I_LED_R_ts1.Time*1000, out.I_LED_R_ts1.Data*1000, '-',  'Color', COL_R, 'LineWidth', 1.3);
    hold on;
    plot(out.I_LED_G_ts1.Time*1000, out.I_LED_G_ts1.Data*1000, '--', 'Color', COL_G, 'LineWidth', 1.3);
    plot(out.I_LED_B_ts1.Time*1000, out.I_LED_B_ts1.Data*1000, '-.', 'Color', COL_B, 'LineWidth', 1.3);
    plot(out.I_LED_W_ts1.Time*1000, out.I_LED_W_ts1.Data*1000, ':',  'Color', COL_W, 'LineWidth', 1.6);
    legend('I_{LED,R}','I_{LED,G}','I_{LED,B}','I_{LED,W}', ...
           'Location','eastoutside');
end
grid on;
xlabel('Time [ms]');
ylabel('LED current [mA]');
title('Node 2: Simscape RGBW LED currents');
xlim([60 simStopTime*1000]);
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

xline(start_bit_begin_ms, '--');
xline(start_bit_end_ms,   '--');
xline(stop_bit_begin_ms,  '--');
xline(stop_bit_end_ms,    '--');

text(start_bit_begin_ms + 0.2, 0.15, 'START BIT = 0');
text(stop_bit_begin_ms + 0.2, 0.85, 'STOP BIT = 1');

%% Final summary

fprintf('\nFinal result\n');
fprintf('Frame sent     = 0x%s\n', dec2hex(frame64, 16));
fprintf('Expected duty  = R %.2f %%, G %.2f %%, B %.2f %%, W %.2f %%\n', ...
        R_duty, G_duty, B_duty, W_duty);
fprintf('Node 1 I_R max = %.4f A\n', max(out.I_LED_R_ts.Data));
if hasNode2
    fprintf('Node 2 I_R max = %.4f A\n', max(out.I_LED_R_ts1.Data));
end
disp('MATLAB + Simulink + Simscape run completed.');

clc;
clear;
close all;

%% =========================================================
% MATLAB -> SIMULINK 64-BIT RGBW FINAL TEST
%
% Communication format:
%
% R = 16 bits
% G = 16 bits
% B = 16 bits
% W = 16 bits
%
% Total = 64 bits
%
% Transmission order:
%
% R -> G -> B -> W
%
% Each 16-bit value is transmitted MSB first.
% ==========================================================


%% ---------------------------------------------------------
% 1. Define test brightness values
% ---------------------------------------------------------

R_Value = uint16(10000);
G_Value = uint16(20000);
B_Value = uint16(30000);
W_Value = uint16(40000);


fprintf('\n');
fprintf('=============================================\n');
fprintf('RGBW TEST VALUES\n');
fprintf('=============================================\n');

fprintf('R = %5d\n', R_Value);
fprintf('G = %5d\n', G_Value);
fprintf('B = %5d\n', B_Value);
fprintf('W = %5d\n', W_Value);


%% ---------------------------------------------------------
% 2. Expected PWM duty cycles
% ---------------------------------------------------------
%
% Counter:
%
% 0 -> 65535
%
% Therefore there are 65536 counter states.

R_duty = double(R_Value) / 65536 * 100;
G_duty = double(G_Value) / 65536 * 100;
B_duty = double(B_Value) / 65536 * 100;
W_duty = double(W_Value) / 65536 * 100;


fprintf('\n');
fprintf('Expected duty cycles:\n');

fprintf('PWM_R = %.2f %%\n', R_duty);
fprintf('PWM_G = %.2f %%\n', G_duty);
fprintf('PWM_B = %.2f %%\n', B_duty);
fprintf('PWM_W = %.2f %%\n', W_duty);


%% ---------------------------------------------------------
% 3. Create one 64-bit reference word
% ---------------------------------------------------------
%
% Register arrangement after reception:
%
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


fprintf('\n');
fprintf('=============================================\n');
fprintf('EXPECTED 64-BIT REGISTER\n');
fprintf('=============================================\n');

fprintf('Hexadecimal frame = 0x%s\n', dec2hex(frame64,16));


%% ---------------------------------------------------------
% 4. Convert each channel into 16 serial bits
% ---------------------------------------------------------
%
% bitget(value,16:-1:1)
%
% means:
%
% bit 16 first = MSB
% ...
% bit 1 last   = LSB

R_bits = double(bitget(R_Value,16:-1:1));
G_bits = double(bitget(G_Value,16:-1:1));
B_bits = double(bitget(B_Value,16:-1:1));
W_bits = double(bitget(W_Value,16:-1:1));


%% ---------------------------------------------------------
% 5. Construct complete serial stream
% ---------------------------------------------------------

serial_bits = [
    R_bits ...
    G_bits ...
    B_bits ...
    W_bits
];


fprintf('\n');
fprintf('=============================================\n');
fprintf('SERIAL DATA\n');
fprintf('=============================================\n');

fprintf('Total number of bits = %d\n', length(serial_bits));

fprintf('\nR bits:\n');
fprintf('%d',R_bits);

fprintf('\n\nG bits:\n');
fprintf('%d',G_bits);

fprintf('\n\nB bits:\n');
fprintf('%d',B_bits);

fprintf('\n\nW bits:\n');
fprintf('%d',W_bits);

fprintf('\n');


%% ---------------------------------------------------------
% 6. Communication timing
% ---------------------------------------------------------
%
% TEST VALUE ONLY.
%
% Each serial bit exists for 1 ms.
%
% The internal Simulink CLK must use the SAME period.

Tbit = 1e-3;                 % 1 ms per bit


% Use four MATLAB samples for each transmitted bit.
%
% This gives:
%
% Ts = 0.25 ms
%
% and makes it easy to place the LE pulse safely
% between clock rising edges.

samples_per_bit = 4;

Ts = Tbit / samples_per_bit;


%% ---------------------------------------------------------
% 7. Total simulation time
% ---------------------------------------------------------
%
% 64 bits x 1 ms = 64 ms serial transmission.
%
% Continue simulation afterwards so we can observe PWM.

frame_time = 64 * Tbit;

simStopTime = 0.22;          % seconds


%% ---------------------------------------------------------
% 8. Create complete time vector
% ---------------------------------------------------------

time = (0:Ts:simStopTime)';

number_of_samples = length(time);


%% ---------------------------------------------------------
% 9. Create Data_In signal
% ---------------------------------------------------------

Data_In_data = zeros(number_of_samples,1);


% Repeat each serial bit four times.

serial_samples = repelem(serial_bits, samples_per_bit);


% Put the 64-bit frame at the beginning of the simulation.

Data_In_data(1:length(serial_samples)) = ...
    serial_samples(:);


%% ---------------------------------------------------------
% 10. Create LE_In signal
% ---------------------------------------------------------
%
% IMPORTANT:
%
% Internal Simulink clock rising edges will occur at:
%
% 0.5 ms
% 1.5 ms
% 2.5 ms
% ...
% 63.5 ms
%
% Therefore the 64th bit is stored at:
%
% 63.5 ms
%
% The NEXT clock rising edge occurs at:
%
% 64.5 ms
%
% LE must become HIGH BETWEEN those two events.
%
% We therefore use:
%
% LE HIGH from 63.75 ms to 64.25 ms.

LE_In_data = zeros(number_of_samples,1);


LE_start = frame_time - Tbit/4;      % 63.75 ms
LE_stop  = frame_time + Tbit/4;      % 64.25 ms


LE_In_data( ...
    time >= LE_start & time <= LE_stop) = 1;


%% ---------------------------------------------------------
% 11. Create Simulink timeseries
% ---------------------------------------------------------

Data_In_sim = timeseries( ...
    Data_In_data, ...
    time);


LE_In_sim = timeseries( ...
    LE_In_data, ...
    time);


%% ---------------------------------------------------------
% 12. Display communication information
% ---------------------------------------------------------

fprintf('\n');
fprintf('=============================================\n');
fprintf('SIMULINK TEST SIGNALS\n');
fprintf('=============================================\n');

fprintf('Data variable = Data_In_sim\n');
fprintf('LE variable   = LE_In_sim\n');

fprintf('\nBit time = %.3f ms\n', ...
    Tbit*1000);

fprintf('64-bit transmission time = %.3f ms\n', ...
    frame_time*1000);

fprintf('LE starts at = %.3f ms\n', ...
    LE_start*1000);

fprintf('LE ends at   = %.3f ms\n', ...
    LE_stop*1000);

fprintf('Simulation stop time = %.3f s\n', ...
    simStopTime);


%% ---------------------------------------------------------
% 13. Verify MATLAB serialization itself
% ---------------------------------------------------------
%
% Reconstruct the 64-bit value from the serial stream.
%
% This checks that the MATLAB sender is correct before
% Simulink is tested.

reconstructed_frame = uint64(0);

for k = 1:64

    reconstructed_frame = ...
        bitshift(reconstructed_frame,1);

    reconstructed_frame = ...
        bitor( ...
            reconstructed_frame, ...
            uint64(serial_bits(k)));

end


fprintf('\n');
fprintf('=============================================\n');
fprintf('MATLAB SERIALIZATION CHECK\n');
fprintf('=============================================\n');

fprintf('Original      = 0x%s\n', ...
    dec2hex(frame64,16));

fprintf('Reconstructed = 0x%s\n', ...
    dec2hex(reconstructed_frame,16));


if reconstructed_frame == frame64

    disp('MATLAB SERIALIZATION: PASS');

else

    error('MATLAB SERIALIZATION: FAILED');

end


%% ---------------------------------------------------------
% 14. Plot MATLAB input signals
% ---------------------------------------------------------

figure;

subplot(2,1,1);

stairs(time*1000,Data_In_data,'LineWidth',1.1);

grid on;

ylabel('Data In');

title('64-bit Serial RGBW Data');

xlim([0 70]);


subplot(2,1,2);

stairs(time*1000,LE_In_data,'LineWidth',1.3);

grid on;

xlabel('Time (ms)');

ylabel('LE');

title('Latch Enable Pulse');

xlim([60 68]);

ylim([-0.1 1.2]);


%% ---------------------------------------------------------
% 15. Plot first 64 transmitted bits
% ---------------------------------------------------------

figure;

stairs(0:63,serial_bits,'LineWidth',1.2);

grid on;

xlabel('Serial Bit Number');

ylabel('Logic Value');

title('64-bit RGBW Transmission');

ylim([-0.1 1.2]);

xticks(0:4:63);
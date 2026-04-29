clc;
clear;
close all;

%% Daisy-chain UART latency model

% Basic requirements
num_segments = 25;
bytes_per_segment = 8;        % RGBW = 4 channels x 16 bits = 8 bytes
baud_rate = 1e6;              % 1 MBd UART

% UART format assumption
% Example: 8N1 means 1 start bit + 8 data bits + 1 stop bit = 10 bits/byte
bits_per_byte = 10;

% Frame overhead
sof_bytes = 1;                % Start-of-frame marker
eof_bytes = 1;                % End-of-frame marker

% Total frame size
payload_bytes = num_segments * bytes_per_segment;
total_frame_bytes = sof_bytes + payload_bytes + eof_bytes;

% Total bits
total_bits = total_frame_bytes * bits_per_byte;

% Total transmission time
total_time_sec = total_bits / baud_rate;
total_time_ms = total_time_sec * 1000;

fprintf('Number of segments: %d\n', num_segments);
fprintf('Payload bytes: %d bytes\n', payload_bytes);
fprintf('Total frame bytes: %d bytes\n', total_frame_bytes);
fprintf('Total UART bits: %d bits\n', total_bits);
fprintf('Total update time: %.3f ms\n', total_time_ms);

% Check requirement
if total_time_ms < 25
    fprintf('PASS: 25th segment receives data within 25 ms.\n');
else
    fprintf('FAIL: 25th segment update time exceeds 25 ms.\n');
end

%% Plot latency vs number of segments

segments = 1:50;
payload_bytes_array = segments * bytes_per_segment;
total_bytes_array = sof_bytes + payload_bytes_array + eof_bytes;
latency_ms = (total_bytes_array * bits_per_byte / baud_rate) * 1000;

figure;
plot(segments, latency_ms, 'LineWidth', 2);
grid on;
xlabel('Number of Segments');
ylabel('Update Latency [ms]');
title('Daisy-Chain UART Update Latency');
yline(25, '--', '25 ms Limit');
%% Compare different baud rates

baud_rates = [115200, 250000, 500000, 1000000, 2000000];

fprintf('\nBaud Rate Comparison:\n');
fprintf('Baud Rate [Bd]     Latency [ms]\n');

for i = 1:length(baud_rates)
    br = baud_rates(i);
    latency = (total_bits / br) * 1000;
    fprintf('%10d        %.3f\n', br, latency);
end

% Plot comparison
figure;
latency_values = (total_bits ./ baud_rates) * 1000;
bar(baud_rates, latency_values);
grid on;
xlabel('Baud Rate [Bd]');
ylabel('Latency for 25 Segments [ms]');
title('Latency vs UART Baud Rate');
yline(25, '--', '25 ms Limit');
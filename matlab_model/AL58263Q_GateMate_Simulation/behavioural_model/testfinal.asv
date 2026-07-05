clc;
clear;
close all;

% =========================================================
% AL58263Q + GateMate FPGA MATLAB Simulation
% Fault detection + Thermal check + RGBW mapping + Serial data
% =========================================================

%% ---------------------------------------------------------
% Basic settings
% ---------------------------------------------------------

num_channels = 16;

MAX_16BIT = 65535;

% Peak current per AL58263Q channel
% This is the ON current when the channel is active.
Imax_A = 20e-3;          % 20 mA

% Data-line voltage after level shifting
% Requirement: data lines between 3 V and 5 V.
logicHighV = 3.3;
logicLowV  = 0;

% Thermal limit
T_max = 155;             % degC, example pre-warning temperature


% true  = create example faults
% false = all channels normal
inject_faults = true;

% If true, the code continues to RGBW and serial plots even if faults exist.
% For real safety behaviour, set this to false.
continue_even_if_fault = true;


%% ---------------------------------------------------------
% Simple fault detection model
% ---------------------------------------------------------
% We simulate output pin voltages of 16 channels.
% Normal channels are assumed around 1.5 V.
% Very low voltage  -> open / short-to-ground type fault
% Very high voltage -> short-to-power type fault

Vout = ones(1, num_channels) * 1.5;

if inject_faults
    Vout(3) = 0.1;    % MATLAB index 3 = OUT2
    Vout(8) = 4.8;    % MATLAB index 8 = OUT7
end

% Detection thresholds
open_threshold  = 0.3;
short_threshold = 4.0;

fault = strings(1, num_channels);

for ch = 1:num_channels

    if Vout(ch) < open_threshold
        fault(ch) = "OPEN or SHORT_TO_GND";

    elseif Vout(ch) > short_threshold
        fault(ch) = "SHORT_TO_POWER";

    else
        fault(ch) = "NORMAL";
    end

end

% Check if any channel has a fault
channel_fault_detected = any(fault ~= "NORMAL");


%% ---------------------------------------------------------
% Thermal model
% ---------------------------------------------------------
% Simple thermal estimation:
%
% Power loss = voltage drop across driver * average current
% Junction temperature = ambient temperature + thermal resistance * power loss

Vdrop = 2.0;                                % volts, example driver voltage drop
Iavg_for_thermal = ones(1, num_channels) * 15e-3;  % 15 mA each channel example

P_loss = sum(Vdrop .* Iavg_for_thermal);    % watts

RthetaJA = 50;                              % degC/W, example value
Tamb = 40;                                  % ambient temperature in degC

Tj = Tamb + RthetaJA * P_loss;

thermal_fault_detected = Tj > T_max;


%% ---------------------------------------------------------
% Print fault and thermal report
% ---------------------------------------------------------

disp('=================================================');
disp('FAULT AND THERMAL CHECK RESULT');
disp('=================================================');

fprintf('Estimated driver power loss = %.3f W\n', P_loss);
fprintf('Estimated junction temperature = %.2f degC\n', Tj);

if thermal_fault_detected
    disp('Thermal status: HOT / THERMAL FAULT');
else
    disp('Thermal status: Normal');
end

disp(' ');
disp('Channel fault status:');
disp('Channel   Vout(V)   Status');

for ch = 1:num_channels
    fprintf('OUT%-2d     %.2f      %s\n', ...
        ch-1, Vout(ch), fault(ch));
end

system_normal = ~channel_fault_detected && ~thermal_fault_detected;

disp(' ');

if system_normal
    disp('SYSTEM STATUS: Everything is NORMAL');
else
    disp('SYSTEM STATUS: Fault detected');
end


%% ---------------------------------------------------------
% Decide whether to continue
% ---------------------------------------------------------

if ~system_normal && ~continue_even_if_fault

    disp(' ');
    disp('Simulation stopped because a fault was detected.');
   

else

    %% -----------------------------------------------------
    % RGBW segment mapping
    % -----------------------------------------------------
    % One AL58263Q has 16 channels.
    % One RGBW segment needs 4 channels.
    %
    % Therefore:
    % 16 channels / 4 channels per RGBW segment = 4 RGBW segments

    rgbw = uint16([
        65535  0      0      10000;   % Segment 1: Red + small white
        0      65535  0      10000;   % Segment 2: Green + small white
        0      0      65535  10000;   % Segment 3: Blue + small white
        20000  20000  20000  65535    % Segment 4: White/mixed light
    ]);

   
    brightness = reshape(rgbw.', 16, 1);

    % Calculate average current for every channel
    average_current_A = Imax_A * double(brightness) / MAX_16BIT;
    average_current_mA = average_current_A * 1000;

    disp(' ');
    disp('=================================================');
    disp('AL58263Q RGBW CHANNEL MAPPING');
    disp('=================================================');
    disp('OUT0=Seg1_R, OUT1=Seg1_G, OUT2=Seg1_B, OUT3=Seg1_W, etc.');
    disp(' ');
    disp('Channel   16-bit brightness   Average current (mA)');

    for ch = 1:num_channels
        fprintf('OUT%-2d     %-8d            %.3f\n', ...
            ch-1, brightness(ch), average_current_mA(ch));
    end

    % Plot average current
    figure;
    bar(0:15, average_current_mA);
    grid on;
    xlabel('AL58263Q Output Channel');
    ylabel('Average Current (mA)');
    title('RGBW Segment Current Mapping');
    xticks(0:15);


    %% -----------------------------------------------------
    % GateMate serial data generation
    % -----------------------------------------------------
    % GateMate sends 16-bit brightness values serially to AL58263Q.
    %
    % One AL58263Q:
    % 16 channels x 16 bits = 256 bits
    %
    % We send OUT15 first, then OUT14, ... finally OUT0.
    % Each value is sent MSB first.

    bits_per_channel = 16;
    total_bits = num_channels * bits_per_channel;

    serial_bits = zeros(1, total_bits);

    bit_index = 1;

    for ch = num_channels:-1:1

        value = brightness(ch);                 % use final 16-channel vector

        bin_string = dec2bin(double(value), 16); % convert to 16-bit binary text

        bits = bin_string - '0';                % convert text '0'/'1' to numbers 0/1

        serial_bits(bit_index:bit_index+15) = bits;

        bit_index = bit_index + 16;
    end

    disp(' ');
    disp('=================================================');
    disp('SERIAL DATA GENERATION');
    disp('=================================================');
    fprintf('Total serial bits = %d\n', length(serial_bits));
    disp('First 32 serial bits:');
    disp(serial_bits(1:32));


    %% -----------------------------------------------------
    % Create DI, DCK, LAT signals
    % -----------------------------------------------------
    % DI  = serial data line
    % DCK = serial clock line
    % LAT = latch signal after all data bits are sent
    %
    % We use voltage levels:
    % logic 0 = 0 V
    % logic 1 = 3.3 V

    num_bits = length(serial_bits);

    % DCK has two samples per bit: low, then high
    DCK = repmat([logicLowV logicHighV], 1, num_bits);

    % DI holds one bit value for two samples
    DI = repelem(serial_bits * logicHighV, 2);

    % LAT is low during data transfer and pulses high at the end
    LAT = zeros(1, length(DI));
    LAT(end-5:end) = logicHighV;

    fprintf('DI length  = %d samples\n', length(DI));
    fprintf('DCK length = %d samples\n', length(DCK));
    fprintf('LAT length = %d samples\n', length(LAT));


    %% -----------------------------------------------------
    % Plot GateMate-generated data signals
    % -----------------------------------------------------

    samples_to_plot = 1:min(120, length(DI));

    figure;

    subplot(3,1,1);
    stairs(samples_to_plot, DCK(samples_to_plot), 'LineWidth', 1.5);
    grid on;
    ylim([-0.2 logicHighV + 0.5]);
    xlabel('Sample');
    ylabel('DCK (V)');
    title('GateMate Generated DCK');

    subplot(3,1,2);
    stairs(samples_to_plot, DI(samples_to_plot), 'LineWidth', 1.5);
    grid on;
    ylim([-0.2 logicHighV + 0.5]);
    xlabel('Sample');
    ylabel('DI (V)');
    title('GateMate Generated DI');

    subplot(3,1,3);
    stairs(1:length(LAT), LAT, 'LineWidth', 1.5);
    grid on;
    ylim([-0.2 logicHighV + 0.5]);
    xlabel('Sample');
    ylabel('LAT (V)');
    title('LAT Pulse After Data Transfer');


    %{

    lat_start = max(1, length(LAT)-80);
    lat_samples = lat_start:length(LAT);

    figure;
    stairs(lat_samples, LAT(lat_samples), 'LineWidth', 1.5);
    grid on;
    ylim([-0.2 logicHighV + 0.5]);
    xlabel('Sample');
    ylabel('LAT (V)');
    title('Zoomed View of LAT Pulse at End of Serial Transfer');
    %}

end
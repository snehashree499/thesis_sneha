%% =========================================================
% Export Simulink PWM_R to LTspice PWL file
% =========================================================

% Take the PWM_R timeseries from Simulink output
PWM_R_ts = out.PWM_R_ts;

% Extract time and PWM logic data
t = PWM_R_ts.Time(:);
pwm_logic = double(PWM_R_ts.Data(:));

% Convert logic signal:
% 0 -> 0 V
% 1 -> 3.3 V
V_HIGH = 3.3;
Vgate = pwm_logic * V_HIGH;

% LTspice folder
ltspice_folder = 'C:\Users\Sneha Shree K\eda\designs\Thesis_Sneha\thesis_sneha\matlab_model\AL58263Q_GateMate_Simulation\LT_SPICE';

% Output file for LTspice
pwl_file = fullfile(ltspice_folder, 'PWM_R_from_Simulink.txt');

% Write time-voltage data for LTspice
writematrix([t Vgate], pwl_file, 'Delimiter', 'tab');

disp('LTspice PWM file created successfully:');
disp(pwl_file);

% Plot to verify exported gate signal
figure;
stairs(t, Vgate, 'LineWidth', 1.2);
grid on;
xlabel('Time (s)');
ylabel('Gate voltage (V)');
title('PWM_R exported from Simulink for LTspice');
ylim([-0.2 3.5]);
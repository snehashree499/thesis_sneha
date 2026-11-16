%% ============================================================
%  EXPORT ALL CHAPTER 4 FIGURES
%
%  Produces, at 300 dpi, into one folder:
%     fig_model_toplevel.png      top level of the model
%     fig_singlewire_rx.png       inside SingleWire_RX
%     fig_digital.png             inside Digital
%     fig_frame_parsing.png       inside 4x16 Bit Parsing
%     fig_pwm_generation.png      inside PWM Generation
%     fig_led_power_stage.png     inside LED_Power_Stage_RGBW
%     fig_serial_waveform.png     serial line with start/stop markers
%     fig_led_currents.png        LED currents, both nodes
%     fig_pwm_node1.png           PWM signals, node 1
%     fig_pwm_node2.png           PWM signals, node 2
%
%  The last two are drawn from logged signals instead of the Scope
%  windows, so they come out on a white background with real signal
%  names instead of "Digital/1" to "Digital/4".
%
%  Run this script on its own. It runs the model itself.
%
%  NOT produced here: flexlink_cutthrough.png - save that file into
%  the same folder by hand.
%  ============================================================

clc;

%% ------------------------------------------------------------
%  1. Turn on signal logging for the eight PWM outputs
%     (changed in memory only - the model file is not modified
%      unless you save it afterwards)
%  ------------------------------------------------------------

modelName = 'GateMate_SingleWire_TxRx_RGBW';
load_system(modelName);

set_param(modelName, 'SignalLogging', 'on');
set_param(modelName, 'SignalLoggingName', 'logsout');

pwmNames = {'PWM_W','PWM_B','PWM_G','PWM_R'};   % Digital outport order

logBlocks = { [modelName '/Digital'],  '_n1'; ...
              [modelName '/Digital1'], '_n2' };

for b = 1:size(logBlocks,1)
    ph = get_param(logBlocks{b,1}, 'PortHandles');
    for k = 1:4
        set_param(ph.Outport(k), ...
            'DataLogging',         'on', ...
            'DataLoggingNameMode', 'Custom', ...
            'DataLoggingName',     [pwmNames{k} logBlocks{b,2}]);
    end
end

fprintf('Signal logging enabled for 8 PWM outputs.\n');

%% ------------------------------------------------------------
%  2. Run the model
%     run_singlewire_txrx_rgbw starts with "clear", so every
%     variable must be defined again after this line.
%  ------------------------------------------------------------

run_singlewire_txrx_rgbw

%% ------------------------------------------------------------
%  3. Settings (re-declared, because the run script cleared them)
%  ------------------------------------------------------------

outdir = ['C:\Users\Sneha Shree K\eda\designs\Thesis_Sneha\' ...
          'thesis_sneha\thesis\content\images\matlab'];

if ~isfolder(outdir)
    mkdir(outdir);
end

m        = 'GateMate_SingleWire_TxRx_RGBW';
pwmNames = {'PWM_W','PWM_B','PWM_G','PWM_R'};

fprintf('\nExporting to:\n  %s\n\n', outdir);

%% ------------------------------------------------------------
%  4. The six Simulink diagrams
%  ------------------------------------------------------------

sysList = { ...
    m,                                 'fig_model_toplevel'; ...
    [m '/SingleWire_RX'],              'fig_singlewire_rx'; ...
    [m '/Digital'],                    'fig_digital'; ...
    [m '/Digital/4x16 Bit Parsing'],   'fig_frame_parsing'; ...
    [m '/Digital/PWM Generation'],     'fig_pwm_generation'; ...
    [m '/LED_Power_Stage_RGBW'],       'fig_led_power_stage' };

for k = 1:size(sysList,1)
    open_system(sysList{k,1});
    print(['-s' sysList{k,1}], '-dpng', '-r300', ...
          fullfile(outdir, [sysList{k,2} '.png']));
    fprintf('  %-26s diagram\n', [sysList{k,2} '.png']);
end

%% ------------------------------------------------------------
%  5. The two figures made by the run script
%     figure 1 = LED currents (both nodes)
%     figure 2 = serial waveform with start/stop markers
%  ------------------------------------------------------------

exportgraphics(figure(1), fullfile(outdir,'fig_led_currents.png'), ...
               'Resolution', 300);
fprintf('  %-26s plot\n', 'fig_led_currents.png');

exportgraphics(figure(2), fullfile(outdir,'fig_serial_waveform.png'), ...
               'Resolution', 300);
fprintf('  %-26s plot\n', 'fig_serial_waveform.png');

%% ------------------------------------------------------------
%  6. PWM figures, drawn from the logged signals
%
%     Four digital signals on one axis would sit on top of each
%     other, so each trace is shifted up by a fixed amount. This
%     is how a logic analyser shows them.
%  ------------------------------------------------------------

if isprop(out,'logsout') && ~isempty(out.logsout)

    offsets  = [4.2 2.8 1.4 0];      % W on top, R at the bottom

    % [NEW] channel colours, in the same order as pwmNames (W B G R)
    % White cannot be shown on a white page, so W is dark grey.
    pwmColors = [0.35 0.35 0.35;     % W
                 0.00 0.30 0.80;     % B
                 0.00 0.55 0.15;     % G
                 0.80 0.00 0.00];    % R
    nodeTag  = {'_n1','_n2'};
    nodeFile = {'fig_pwm_node1.png','fig_pwm_node2.png'};
    nodeName = {'Node 1','Node 2'};

    for n = 1:2
        figure('Color','w');
        hold on; grid on;

        ok = true;
        for k = 1:4
            sigName = [pwmNames{k} nodeTag{n}];
            try
                s = out.logsout.getElement(sigName);
            catch
                warning('Signal %s not found in logsout.', sigName);
                ok = false;
                break
            end
            stairs(s.Values.Time*1000, ...
                   double(s.Values.Data) + offsets(k), ...
                   'Color', pwmColors(k,:), 'LineWidth', 1.2);
        end

        if ~ok
            close(gcf);
            break
        end

        yticks(sort(offsets) + 0.5);
        yticklabels(fliplr(pwmNames));     % R, G, B, W bottom to top
        ylim([-0.4 5.8]);
        xlim([60 220]);
        xlabel('Time [ms]');
        title([nodeName{n} ': PWM outputs']);
        set(gca,'TickLabelInterpreter','none');

        exportgraphics(gcf, fullfile(outdir, nodeFile{n}), ...
                       'Resolution', 300);
        fprintf('  %-26s plot\n', nodeFile{n});
    end

else
    warning(['No logged signals found. Export the two Scope windows ' ...
             'by hand instead: File > Print to Figure, then ' ...
             'exportgraphics(gcf, ..., ''Resolution'', 300).']);
end

%% ------------------------------------------------------------
%  7. Check what landed in the folder
%  ------------------------------------------------------------

fprintf('\nFiles now in the figure folder:\n');
d = dir(fullfile(outdir,'*.png'));
for k = 1:numel(d)
    fprintf('  %-30s %7.0f kB\n', d(k).name, d(k).bytes/1024);
end

fprintf('\nStill to add by hand: flexlink_cutthrough.png\n');
disp('Chapter 4 figure export finished.');

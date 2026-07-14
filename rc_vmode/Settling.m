function transient_settling_analysis()
    clc; clear; close all;

    %% User settings
    files  = {'Trans10n.txt','Trans50n.txt','Trans500n.txt','Trans2u.txt','Trans10u.txt'};
    labels = {'10n','50n','500n','2u','10u'};

    % Settling band
    tol = 0.02;   % 2% settling band

    % Known target levels
    Vhigh =  2.5;
    Vlow  = -2.5;

    % Known command timing from your LTspice source
    t_rise_nom = 10e-6;   % first transition around 10 us
    t_fall_nom = 1e-3;    % second transition around 1 ms

    % Search windows around the transitions
    rise_window = [5e-6, 100e-6];
    fall_window = [0.95e-3, 1.10e-3];

    %% Containers
    n = numel(files);
    Results = table('Size',[n 7], ...
        'VariableTypes', {'string','double','double','double','double','double','double'}, ...
        'VariableNames', {'CL','OS_rise_pct','US_fall_pct', ...
                          'ts_rise_us','ts_fall_us','t_rise_us','t_fall_us'});

    fig = figure('Color','w','Position',[100 100 1100 650]);
    hold on; grid on;
    xlabel('Time (ms)');
    ylabel('V_{out} (V)');
    title('Compensated Voltage-Mode Transient Responses');
    colors = lines(n);

    for k = 1:n
        %% Read file
        T = readtable(files{k}, 'FileType','text');
        t = T{:,1};          % time in seconds
        v = T{:,2};          % V(vout)

        % Plot
        plot(t*1e3, v, 'LineWidth', 1.6, 'Color', colors(k,:));

        %% Detect transition indices within known windows
        idx_rise_window = find(t >= rise_window(1) & t <= rise_window(2));
        idx_fall_window = find(t >= fall_window(1) & t <= fall_window(2));

        if isempty(idx_rise_window) || isempty(idx_fall_window)
            error('Time windows do not overlap data for file %s', files{k});
        end

        dvdt = gradient(v, t);

        % Rising edge: largest positive slope within rise window
        [~, rel_rise] = max(dvdt(idx_rise_window));
        idx_rise = idx_rise_window(rel_rise);
        t_rise = t(idx_rise);

        % Falling edge: largest negative slope within fall window
        [~, rel_fall] = min(dvdt(idx_fall_window));
        idx_fall = idx_fall_window(rel_fall);
        t_fall = t(idx_fall);

        %% High plateau estimate: after rise settles and before fall
        high_region = find(t >= 0.2e-3 & t <= 0.8e-3);
        if isempty(high_region)
            error('Could not find high plateau region for file %s', files{k});
        end
        Vhigh_est = mean(v(high_region));

        %% Low plateau estimate: well after the falling edge
        low_region = find(t >= 1.4e-3 & t <= 1.9e-3);
        if isempty(low_region)
            error('Could not find low plateau region for file %s', files{k});
        end
        Vlow_est = mean(v(low_region));

        % Use known intended values if they are appropriate
        % If you prefer measured plateaus, replace with Vhigh_est and Vlow_est
        Vh = Vhigh;
        Vl = Vlow;

        %% Rising edge metrics
        rise_segment = find(t >= t_rise & t <= t_fall);
        tr = t(rise_segment);
        vr = v(rise_segment);

        v_peak_rise = max(vr);
        OS_rise_pct = max(0, (v_peak_rise - Vh)/abs(Vh) * 100);

        rise_low  = Vh - tol*abs(Vh);
        rise_high = Vh + tol*abs(Vh);

        idx_settle_rise = find_settling_index(vr, rise_low, rise_high);
        if isnan(idx_settle_rise)
            ts_rise = NaN;
        else
            ts_rise = tr(idx_settle_rise) - t_rise;
        end

        %% Falling edge metrics
        fall_segment = find(t >= t_fall);
        tf = t(fall_segment);
        vf = v(fall_segment);

        v_min_fall = min(vf);
        US_fall_pct = max(0, (Vl - v_min_fall)/abs(Vl) * 100);

        fall_low  = Vl - tol*abs(Vl);
        fall_high = Vl + tol*abs(Vl);

        idx_settle_fall = find_settling_index(vf, fall_low, fall_high);
        if isnan(idx_settle_fall)
            ts_fall = NaN;
        else
            ts_fall = tf(idx_settle_fall) - t_fall;
        end

        %% Store
        Results.CL(k)          = string(labels{k});
        Results.OS_rise_pct(k) = OS_rise_pct;
        Results.US_fall_pct(k) = US_fall_pct;
        Results.ts_rise_us(k)  = ts_rise * 1e6;
        Results.ts_fall_us(k)  = ts_fall * 1e6;
        Results.t_rise_us(k)   = t_rise * 1e6;
        Results.t_fall_us(k)   = t_fall * 1e6;
    end

    legend(labels, 'Location','best');

    %% Print neat command-window summary
    fprintf('\n%-8s %-10s %-10s %-12s %-12s %-12s %-12s\n', ...
        'CL','OS_rise%','US_fall%','ts_rise(us)','ts_fall(us)','t_rise(us)','t_fall(us)');
    fprintf('%s\n', repmat('-',1,82));
    for k = 1:height(Results)
        fprintf('%-8s %-10.2f %-10.2f %-12.3f %-12.3f %-12.3f %-12.3f\n', ...
            Results.CL{k}, Results.OS_rise_pct(k), Results.US_fall_pct(k), ...
            Results.ts_rise_us(k), Results.ts_fall_us(k), ...
            Results.t_rise_us(k), Results.t_fall_us(k));
    end

    %% Compact table for screenshot
    Display = table;
    Display.CL          = cellstr(Results.CL);
    Display.OS_rise_pct = round(Results.OS_rise_pct,2);
    Display.US_fall_pct = round(Results.US_fall_pct,2);
    Display.ts_rise_us  = round(Results.ts_rise_us,3);
    Display.ts_fall_us  = round(Results.ts_fall_us,3);

    figTable = uifigure('Name','Transient Metrics', ...
                        'Position',[150 150 720 260], ...
                        'Color','w');

    uitable(figTable, ...
        'Data', table2cell(Display), ...
        'ColumnName', {'CL','OS rise (%)','US fall (%)','t_s rise (us)','t_s fall (us)'}, ...
        'Position', [10 10 700 240], ...
        'FontSize', 11);

    %% Save outputs
    saveas(fig, 'Transient_Responses_All.png');
    exportapp(figTable, 'Transient_Metrics_Table.png');
    writetable(Results, 'Transient_Metrics.csv');
end

function idx_settle = find_settling_index(v, lowLim, highLim)
    idx_settle = NaN;
    inside = (v >= lowLim) & (v <= highLim);

    for i = 1:numel(v)
        if all(inside(i:end))
            idx_settle = i;
            return;
        end
    end
end
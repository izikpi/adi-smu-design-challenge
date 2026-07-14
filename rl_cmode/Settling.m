function RL_transient_settling_analysis()
    clc; clear; close all;

    %% User settings
    filename = 'Settling.txt';

    % Settling criterion
    tol = 0.02;   % 2%

    % Known command timing
    rise_window = [5e-6, 100e-6];
    fall_window = [0.95e-3, 1.10e-3];

    %% Read raw file
    rawText = fileread(filename);
    rawLines = regexp(rawText, '\r\n|\n|\r', 'split');

    %% Parse stepped LTspice transient export
    steps = struct('label', {}, 'time', {}, 'iout', {});
    k = 0;

    for i = 1:numel(rawLines)
        line = strtrim(rawLines{i});
        if isempty(line)
            continue;
        end

        % New step block
        if contains(line, 'Step Information:')
            k = k + 1;
            lbl = regexprep(line, 'Step Information:\s*', '');
            lbl = regexprep(lbl, '\(Step:.*\)', '');
            lbl = strtrim(lbl);
            lbl = strrep(lbl, 'L=', '');
            steps(k).label = lbl;
            steps(k).time = [];
            steps(k).iout = [];
            continue;
        end

        % Skip header row
        if startsWith(line, 'time')
            continue;
        end

        % Parse numeric row
        tok = regexp(line, ...
            '^\s*([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)\s+([+-]?\d*\.?\d+(?:[eE][+-]?\d+)?)$', ...
            'tokens', 'once');

        if ~isempty(tok) && k > 0
            steps(k).time(end+1,1) = str2double(tok{1});
            steps(k).iout(end+1,1) = str2double(tok{2});
        end
    end

    if isempty(steps)
        error('No stepped transient data found in %s', filename);
    end

    %% Plot all traces
    n = numel(steps);
    cmap = lines(n);

    fig = figure('Color','w','Position',[100 100 1100 650]);
    hold on; grid on;
    xlabel('Time (ms)');
    ylabel('I_{out} = I(RL)+I(L) (A)');
    title('RL-Load Transient Responses');

    for k = 1:n
        plot(steps(k).time*1e3, steps(k).iout, '-', ...
            'LineWidth', 1.6, ...
            'Color', cmap(k,:));
    end
    legend({steps.label}, 'Location', 'best');

    %% Extract metrics
    Results = table('Size',[n 7], ...
        'VariableTypes', {'string','double','double','double','double','double','double'}, ...
        'VariableNames', {'L','OS_rise_pct','US_fall_pct', ...
                          'ts_rise_us','ts_fall_us','t_rise_us','t_fall_us'});

    for k = 1:n
        t = steps(k).time;
        iout = steps(k).iout;

        didt = gradient(iout, t);

        idx_rise_window = find(t >= rise_window(1) & t <= rise_window(2));
        idx_fall_window = find(t >= fall_window(1) & t <= fall_window(2));

        if isempty(idx_rise_window) || isempty(idx_fall_window)
            error('Time windows do not overlap data for step %s', steps(k).label);
        end

        % Rising edge: largest positive slope
        [~, rel_rise] = max(didt(idx_rise_window));
        idx_rise = idx_rise_window(rel_rise);
        t_rise = t(idx_rise);

        % Falling edge: largest negative slope
        [~, rel_fall] = min(didt(idx_fall_window));
        idx_fall = idx_fall_window(rel_fall);
        t_fall = t(idx_fall);

        % Positive plateau, before the falling edge
        high_region = find(t >= 0.2e-3 & t <= 0.8e-3);
        if isempty(high_region)
            error('Could not find positive-current plateau region for step %s', steps(k).label);
        end
        Ihigh = mean(iout(high_region));

        % Negative plateau, after the falling edge
        low_region = find(t >= 1.6e-3 & t <= 1.95e-3);
        if isempty(low_region)
            error('Could not find negative-current plateau region for step %s', steps(k).label);
        end
        Ilow = mean(iout(low_region));

        %% Rising edge metrics
        rise_segment = find(t >= t_rise & t <= t_fall);
        tr = t(rise_segment);
        ir = iout(rise_segment);

        i_peak_rise = max(ir);
        OS_rise_pct = max(0, (i_peak_rise - Ihigh)/abs(Ihigh) * 100);

        rise_low  = Ihigh - tol*abs(Ihigh);
        rise_high = Ihigh + tol*abs(Ihigh);

        idx_settle_rise = find_settling_index(ir, rise_low, rise_high);
        if isnan(idx_settle_rise)
            ts_rise = NaN;
        else
            ts_rise = tr(idx_settle_rise) - t_rise;
        end

        %% Falling edge metrics
        fall_segment = find(t >= t_fall);
        tf = t(fall_segment);
        iff = iout(fall_segment);

        i_min_fall = min(iff);
        US_fall_pct = max(0, (Ilow - i_min_fall)/abs(Ilow) * 100);

        fall_low  = Ilow - tol*abs(Ilow);
        fall_high = Ilow + tol*abs(Ilow);

        idx_settle_fall = find_settling_index(iff, fall_low, fall_high);
        if isnan(idx_settle_fall)
            ts_fall = NaN;
        else
            ts_fall = tf(idx_settle_fall) - t_fall;
        end

        Results.L(k)           = string(steps(k).label);
        Results.OS_rise_pct(k) = OS_rise_pct;
        Results.US_fall_pct(k) = US_fall_pct;
        Results.ts_rise_us(k)  = ts_rise * 1e6;
        Results.ts_fall_us(k)  = ts_fall * 1e6;
        Results.t_rise_us(k)   = t_rise * 1e6;
        Results.t_fall_us(k)   = t_fall * 1e6;
    end

    %% Neat command window output
    fprintf('\n%-8s %-12s %-12s %-12s %-12s %-12s %-12s\n', ...
        'L','OS_rise%','US_fall%','ts_rise(us)','ts_fall(us)','t_rise(us)','t_fall(us)');
    fprintf('%s\n', repmat('-',1,88));

    for k = 1:height(Results)
        if isnan(Results.ts_rise_us(k))
            tsr = 'N/A';
        else
            tsr = sprintf('%.3f', Results.ts_rise_us(k));
        end

        if isnan(Results.ts_fall_us(k))
            tsf = 'N/A';
        else
            tsf = sprintf('%.3f', Results.ts_fall_us(k));
        end

        fprintf('%-8s %-12.2f %-12.2f %-12s %-12s %-12.3f %-12.3f\n', ...
            Results.L{k}, Results.OS_rise_pct(k), Results.US_fall_pct(k), ...
            tsr, tsf, Results.t_rise_us(k), Results.t_fall_us(k));
    end

    %% Compact display table
    Display = table;
    Display.L           = cellstr(Results.L);
    Display.OS_rise_pct = round(Results.OS_rise_pct,2);
    Display.US_fall_pct = round(Results.US_fall_pct,2);
    Display.ts_rise_us  = cell(height(Results),1);
    Display.ts_fall_us  = cell(height(Results),1);

    for k = 1:height(Results)
        if isnan(Results.ts_rise_us(k))
            Display.ts_rise_us{k} = 'N/A';
        else
            Display.ts_rise_us{k} = sprintf('%.3f', Results.ts_rise_us(k));
        end

        if isnan(Results.ts_fall_us(k))
            Display.ts_fall_us{k} = 'N/A';
        else
            Display.ts_fall_us{k} = sprintf('%.3f', Results.ts_fall_us(k));
        end
    end

    figTable = uifigure('Name','RL Transient Metrics', ...
                        'Position',[150 150 760 320], ...
                        'Color','w');

    uitable(figTable, ...
        'Data', table2cell(Display), ...
        'ColumnName', {'L','OS rise (%)','US fall (%)','t_s rise (us)','t_s fall (us)'}, ...
        'Position', [10 10 740 300], ...
        'FontSize', 11);

    %% Save outputs
    saveas(fig, 'RL_Transient_Responses_All.png');
    exportapp(figTable, 'RL_Transient_Metrics_Table.png');
    writetable(Results, 'RL_Transient_Metrics.csv');
end

function idx_settle = find_settling_index(x, lowLim, highLim)
    idx_settle = NaN;
    inside = (x >= lowLim) & (x <= highLim);

    for i = 1:numel(x)
        if all(inside(i:end))
            idx_settle = i;
            return;
        end
    end
end
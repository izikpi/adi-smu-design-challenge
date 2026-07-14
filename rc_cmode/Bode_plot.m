function Bode_plot_report_ready()
    clc; clearvars; close all;

    %% File
    filepath = 'Bode Plot Com.txt';
    if ~isfile(filepath)
        error('File "%s" not found in the current directory.', filepath);
    end

    filetext = fileread(filepath);

    %% Split by LTspice step headers
    stepBlocks = strsplit(filetext, 'Step Information: Cl=');

    %% Create figure for Bode plots
    fig = figure('Name', 'Bode Plot Stability Analysis', ...
                 'Position', [100, 100, 1100, 760], ...
                 'Color', 'w');

    ax_mag = subplot(2,1,1);
    hold(ax_mag, 'on'); grid(ax_mag, 'on'); set(ax_mag, 'XScale', 'log');
    ylabel(ax_mag, 'Magnitude (dB)');
    title(ax_mag, 'Extracted LTspice Loop Gain');
    yline(ax_mag, 0, 'k--', '0 dB', 'LineWidth', 0.9);

    ax_phase = subplot(2,1,2);
    hold(ax_phase, 'on'); grid(ax_phase, 'on'); set(ax_phase, 'XScale', 'log');
    ylabel(ax_phase, 'Phase (Degrees)');
    xlabel(ax_phase, 'Frequency (Hz)');
    yline(ax_phase, -180, 'k--', '-180^\circ', 'LineWidth', 0.9);

    %% Containers for extracted results
    legends = {};
    colors = lines(length(stepBlocks)-1);

    CL_list   = {};
    fgc_list  = [];
    fpc_list  = [];
    GM_list   = [];
    PM_list   = [];
    Stat_list = {};

    x_all_min = inf;
    x_all_max = -inf;

    %% Parse each step
    for i = 2:length(stepBlocks)
        block = stepBlocks{i};

        % First token is capacitance label
        tokens = textscan(block, '%s', 1);
        cl_val = strtrim(tokens{1}{1});

        % Extract numeric rows
        pattern = '([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)\s*\(([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)dB,\s*([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)°\)';
        matches = regexp(block, pattern, 'tokens');

        if isempty(matches)
            continue;
        end

        N = length(matches);
        f_arr = zeros(N,1);
        m_arr = zeros(N,1);
        p_arr = zeros(N,1);

        for k = 1:N
            f_arr(k) = str2double(matches{k}{1});
            m_arr(k) = str2double(matches{k}{2});
            p_arr(k) = str2double(matches{k}{3});
        end

        % Track overall frequency range
        x_all_min = min(x_all_min, min(f_arr));
        x_all_max = max(x_all_max, max(f_arr));

        % Unwrap phase for analysis and plotting
        p_unwrapped = unwrap(p_arr*pi/180)*180/pi;

        % Plot with solid colored lines
        c_idx = i - 1;
        plot(ax_mag, f_arr, m_arr, '-', 'LineWidth', 1.8, 'Color', colors(c_idx,:));
        plot(ax_phase, f_arr, p_unwrapped, '-', 'LineWidth', 1.8, 'Color', colors(c_idx,:));
        legends{end+1} = cl_val;

        % Log-frequency for interpolation
        log_f = log10(f_arr);

        fgc = NaN; fpc = NaN; gm = NaN; pm = NaN;

        % ---- Gain crossover: use LAST 0 dB crossing
        idx_gc_all = find(m_arr(1:end-1).*m_arr(2:end) <= 0);
        if ~isempty(idx_gc_all)
            idx_gc = idx_gc_all(end);
            log_fgc = interp1(m_arr(idx_gc:idx_gc+1), log_f(idx_gc:idx_gc+1), 0, 'linear');
            fgc = 10^log_fgc;
            pm = interp1(log_f, p_unwrapped, log_fgc, 'linear') + 180;
        end

        % ---- Phase crossover: use FIRST -180 crossing
        idx_pc_all = find((p_unwrapped(1:end-1)+180).*(p_unwrapped(2:end)+180) <= 0);
        if ~isempty(idx_pc_all)
            idx_pc = idx_pc_all(1);
            log_fpc = interp1(p_unwrapped(idx_pc:idx_pc+1), log_f(idx_pc:idx_pc+1), -180, 'linear');
            fpc = 10^log_fpc;
            gm = -interp1(log_f, m_arr, log_fpc, 'linear');
        end

        % ---- Stability classification
        if isnan(pm) || isnan(gm)
            status = 'N/A';
        elseif pm >= 45 && gm >= 6
            status = 'Stable';
        elseif pm > 0 && gm > 0
            status = 'Marginally Stable';
        else
            status = 'Unstable';
        end

        % Store
        CL_list{end+1,1}   = cl_val;
        fgc_list(end+1,1)  = fgc/1e6;
        fpc_list(end+1,1)  = fpc/1e6;
        GM_list(end+1,1)   = gm;
        PM_list(end+1,1)   = pm;
        Stat_list{end+1,1} = status;
    end

    % Tight x-limits to actual data range
    xlim(ax_mag, [x_all_min x_all_max]);
    xlim(ax_phase, [x_all_min x_all_max]);

    legend(ax_mag, legends, 'Location', 'eastoutside');
    legend(ax_phase, legends, 'Location', 'eastoutside');

    %% Build compact results table
    T = table( ...
        CL_list, ...
        round(fgc_list,4), ...
        round(fpc_list,4), ...
        round(GM_list,3), ...
        round(PM_list,3), ...
        Stat_list, ...
        'VariableNames', {'CL','fgc_MHz','fpc_MHz','GM_dB','PM_deg','Status'});

    %% Neat command-window table
    fprintf('\n%-8s %-10s %-10s %-10s %-10s %-18s\n', ...
        'CL', 'fgc_MHz', 'fpc_MHz', 'GM_dB', 'PM_deg', 'Status');
    fprintf('%s\n', repmat('-', 1, 74));

    for i = 1:height(T)
        fprintf('%-8s %-10.2f %-10.2f %-10.1f %-10.1f %-18s\n', ...
            T.CL{i}, T.fgc_MHz(i), T.fpc_MHz(i), T.GM_dB(i), T.PM_deg(i), T.Status{i});
    end

    %% Colored table figure
    figTable = uifigure('Name','Extracted Loop Gain Parameters', ...
                        'Position',[150 150 900 420], ...
                        'Color','w');

    cellData = table2cell(T);

    uit = uitable(figTable, ...
        'Data', cellData, ...
        'ColumnName', {'CL','f_gc (MHz)','f_pc (MHz)','GM (dB)','PM (deg)','Status'}, ...
        'Position', [10 10 880 400], ...
        'FontSize', 11);

    % Apply row colors based on status
    for i = 1:height(T)
        style = uistyle;
        switch T.Status{i}
            case 'Stable'
                style.BackgroundColor = [0.85 1.00 0.85];
            case 'Marginally Stable'
                style.BackgroundColor = [0.85 0.92 1.00];
            case 'Unstable'
                style.BackgroundColor = [1.00 0.85 0.85];
            otherwise
                style.BackgroundColor = [1.00 1.00 1.00];
        end
        addStyle(uit, style, 'row', i);
    end

    %% Optional save
    saveas(fig, 'LoopGain_BodePlot.png');
    exportapp(figTable, 'LoopGain_Table.png');
    writetable(T, 'LoopGain_Extracted_Parameters.csv');
end
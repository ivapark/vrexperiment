% ----------------------------------------------------------------------
% xyz_projection_butterfly.m
%
% Butterfly plot: Left penalty on bottom, Right penalty on top.
% For each axis (X, Y, Z), one figure with 9 subplots (one per target).
% Each subplot shows:
%   - No-Penalty condition (as reference)
%   - Penalty on left (blue, labeled as negative)
%   - Penalty on right (magenta, labeled as right)
% ----------------------------------------------------------------------
% Notes:
% Simple visualization (model free)
% Aiming to answer: how much does aiming points shift when there's penalty
%   and wherther the shift differ across three axes
% ----------------------------------------------------------------------
% Input(s) :
% _processed_data_disPenDirec.mat from analyze_targets_1.m
% ----------------------------------------------------------------------
% Output(s):
% figures
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last edited by : Rachel Chen
% Last update : 2026-02-27
% Project : VR
% Version :4.0

%% ================= SWITCHES =================
save_fig = 1;

% Which figure to plot?
plot_his_butterfly = 1;
plot_singGaussian_butterfly = 1;
plot_allGaussian_butterfly = 1;
%% ================= CONFIGURATIONS =================

% Comment out since should be in fxnConfig.m now
% subjectID = {'RC'};

% Colors
% col_np    = [210, 210, 210] / 255;  % gray (No-penalty)
% col_p_neg = [67, 112, 180] / 255;   % blue (Left penalty, e.g., negative)
% col_p_pos = [195, 0, 120] / 255;    % magenta (Right penalty , e.g., positive)
%
% ax_colors = [[41,157,143]./255;     % X - green?
%           [233,196,106]./255;       % Y - yellow
%           [106, 92, 164]./255];     % Z - deep purple

n_bins = 40;

axis_labels = {'X (mm)', 'Y (mm)', 'Z (mm)'};

%% ================= LOAD DATA =================
matFileName = fullfile(output_process_Dir, [subID '_processed_data_disPenDirec.mat']);

if exist(matFileName, 'file')
    load(matFileName, 'ENDPOINT_NP', 'MU_NP', 'COV_NP', ...
        'ENDPOINT_P_NEG', 'MU_P_NEG', 'COV_P_NEG', ...
        'ENDPOINT_P_POS', 'MU_P_POS', 'COV_P_POS', ...
        'TARGET', 'neg_label', 'pos_label');
else
    error('No file found for: %s', matFileName);
end

%% ================= PLOT: HISTOGRAM BUTTERFLY =================
if plot_his_butterfly
    for ax = 1:3
        figure('Color', 'w', 'Name', sprintf('%s - %s Axis Projection Histogram', subID, axis_names{ax}), ...
            'Position', [50, 50, 1400, 1000]);

        sgtitle(sprintf('Axes Projection Histogram — %s | Axis: %s | %s (bottom) vs %s (top)', ...
            subID, axis_names{ax}, neg_label, pos_label), ...
            'FontSize', 16, 'FontWeight', 'bold');

        for row = 1:3
            for col = 1:3
                ii = target_order(row, col);
                subplot_idx = (row - 1) * 3 + col;
                subplot(3, 3, subplot_idx);
                hold on;

                targ_val = TARGET{ii}(ax);

                % --- Compute Gaussians ---
                % No-Penalty
                has_np = ~isempty(ENDPOINT_NP{ii});
                if has_np
                    mu_np = MU_NP{ii}(ax);
                    sig_np = sqrt(COV_NP{ii}(ax, ax));
                    x_np = linspace(mu_np - 4*sig_np, mu_np + 4*sig_np, 200);
                    y_np = normpdf(x_np, mu_np, sig_np);
                end

                % Penalty Negative (e.g., Left)
                has_pn = ~isempty(ENDPOINT_P_NEG{ii});
                if has_pn
                    mu_pn = MU_P_NEG{ii}(ax);
                    sig_pn = sqrt(COV_P_NEG{ii}(ax, ax));
                    x_pn = linspace(mu_pn - 4*sig_pn, mu_pn + 4*sig_pn, 200);
                    y_pn = normpdf(x_pn, mu_pn, sig_pn);
                end

                % Penalty Positive (e.g., Right)
                has_pp = ~isempty(ENDPOINT_P_POS{ii});
                if has_pp
                    mu_pp = MU_P_POS{ii}(ax);
                    sig_pp = sqrt(COV_P_POS{ii}(ax, ax));
                    x_pp = linspace(mu_pp - 4*sig_pp, mu_pp + 4*sig_pp, 200);
                    y_pp = normpdf(x_pp, mu_pp, sig_pp);
                end

                % --- Determine shared bin edges ---
                all_data = [];
                if ~isempty(ENDPOINT_NP{ii}),    all_data = [all_data; ENDPOINT_NP{ii}(:, ax)]; end
                if ~isempty(ENDPOINT_P_NEG{ii}), all_data = [all_data; ENDPOINT_P_NEG{ii}(:, ax)]; end
                if ~isempty(ENDPOINT_P_POS{ii}), all_data = [all_data; ENDPOINT_P_POS{ii}(:, ax)]; end
                bin_edges = linspace(min(all_data) - 2, max(all_data) + 2, n_bins + 1);

                % --- P_POS histogram (top, positive) ---
                if ~isempty(ENDPOINT_P_POS{ii})
                    data_pp = ENDPOINT_P_POS{ii}(:, ax);
                    [counts_pp, ~] = histcounts(data_pp, bin_edges, 'Normalization', 'pdf');
                    bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;
                    bar(bin_centers, counts_pp, 1, 'FaceColor', col_p_pos, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
                    plot([mu_pp, mu_pp], [0, max(y_pp)], '-', 'Color', col_p_pos, 'LineWidth', 2);
                end

                % --- P_NEG histogram (bottom, negative) ---
                if ~isempty(ENDPOINT_P_NEG{ii})
                    data_pn = ENDPOINT_P_NEG{ii}(:, ax);
                    [counts_pn, ~] = histcounts(data_pn, bin_edges, 'Normalization', 'pdf');
                    bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;
                    bar(bin_centers, -counts_pn, 1, 'FaceColor', col_p_neg, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
                    plot([mu_pn, mu_pn], [0, -max(y_pn)], '-', 'Color', col_p_neg, 'LineWidth', 2);
                end

                % --- NP histogram outline (both sides, reference) ---
                if ~isempty(ENDPOINT_NP{ii})
                    data_np = ENDPOINT_NP{ii}(:, ax);
                    [counts_np, ~] = histcounts(data_np, bin_edges, 'Normalization', 'pdf');
                    bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;
                    stairs([bin_edges(1), bin_centers, bin_edges(end)], [0, counts_np, 0], ...
                        '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    stairs([bin_edges(1), bin_centers, bin_edges(end)], [0, -counts_np, 0], ...
                        '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    % NP mean lines
                    plot([mu_np, mu_np], [0, max(y_np)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
                    plot([mu_np, mu_np], [0, -max(y_np)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);

                end

                % --- Target zone shading ---
                yl_curr = ylim;
                fill([targ_val - 20, targ_val + 20, targ_val + 20, targ_val - 20], ...
                    [yl_curr(1), yl_curr(1), yl_curr(2), yl_curr(2)], ...
                    'r', 'FaceAlpha', 0.05, 'EdgeColor', 'none', 'HandleVisibility', 'off');

                % --- Target line and zero line ---
                xline(targ_val, 'r:', 'LineWidth', 1);
                yline(0, 'k-', 'LineWidth', 0.5);

                % --- y-axis absolute values ---
                yt = yticks;
                yticklabels(num2str(abs(yt)'));

                xlabel(axis_labels{ax});
                ylabel('Density');
                title(sprintf('T%d', ii), 'FontSize', 11);

                % --- Legend ---
                if row == 1 && col == 3
                    h_leg1 = fill(nan, nan,col_p_pos, 'FaceAlpha', 0.5, 'EdgeColor', 'k');
                    h_leg2 = fill(nan, nan,col_p_neg, 'FaceAlpha', 0.5, 'EdgeColor', 'k');
                    h_leg3 = plot(nan, nan, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    h_leg4 = xline(nan, 'r:', 'LineWidth', 2);
                    lg = legend([h_leg1, h_leg2, h_leg3, h_leg4], ...
                        {[pos_label], [neg_label], 'No-Penalty (ref)','Target'},'FontSize', 5);
                    lg.Units = 'normalized';
                    lg.Position = [0.91, 0.8, 0.07, 0.10]; % [left, bottom, width, height]
                end
            end
        end

        set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

        if save_fig
            figDir = fullfile(pwd, 'Figures',subID, 'xyz_projection_butterfly');
            if ~exist(figDir, 'dir'), mkdir(figDir); end
            saveas(gcf, fullfile(figDir, sprintf('%s_Axis%s_projection_hist_butterfly.png', subID, axis_names{ax})));
        end

    end % axes
end % plot_his_butterfly

%% ================= PLOT: FITTED GAUSSIAN BUTTERFLY (ONE FIGURE PER AXIS) =================
if plot_singGaussian_butterfly
    for ax = 1:3
        figure('Color', 'w', 'Name', sprintf('%s - %s Axis Butterfly', subID, axis_names{ax}), ...
            'Position', [50, 50, 1400, 1000]);

        sgtitle(sprintf('fitted Gaussian — %s | Axis: %s | %s (left) vs %s (right)', ...
            subID, axis_names{ax}, neg_label, pos_label), ...
            'FontSize', 16, 'FontWeight', 'bold');

        for row = 1:3
            for col = 1:3
                ii = target_order(row, col);
                subplot_idx = (row - 1) * 3 + col;
                subplot(3, 3, subplot_idx);
                hold on;

                targ_val = TARGET{ii}(ax);

                % --- Compute Gaussians ---
                % No-Penalty
                has_np = ~isempty(ENDPOINT_NP{ii});
                if has_np
                    mu_np = MU_NP{ii}(ax);
                    sig_np = sqrt(COV_NP{ii}(ax, ax));
                    x_np = linspace(mu_np - 4*sig_np, mu_np + 4*sig_np, 200);
                    y_np = normpdf(x_np, mu_np, sig_np);
                end

                % % Penalty Negative (e.g., Left)
                has_pn = ~isempty(ENDPOINT_P_NEG{ii});
                if has_pn
                    mu_pn = MU_P_NEG{ii}(ax);
                    sig_pn = sqrt(COV_P_NEG{ii}(ax, ax));
                    x_pn = linspace(mu_pn - 4*sig_pn, mu_pn + 4*sig_pn, 200);
                    y_pn = normpdf(x_pn, mu_pn, sig_pn);
                end

                % % Penalty Positive (e.g., Right)
                has_pp = ~isempty(ENDPOINT_P_POS{ii});
                if has_pp
                    mu_pp = MU_P_POS{ii}(ax);
                    sig_pp = sqrt(COV_P_POS{ii}(ax, ax));
                    x_pp = linspace(mu_pp - 4*sig_pp, mu_pp + 4*sig_pp, 200);
                    y_pp = normpdf(x_pp, mu_pp, sig_pp);
                end

                % --- Plot: Right side (positive y) = P_POS ---
                if has_pp
                    fill([x_pp, fliplr(x_pp)], [y_pp, zeros(1, length(y_pp))], ...
                        col_p_pos, 'FaceAlpha', 0.4, 'EdgeColor', col_p_pos, 'LineWidth', 1.5);
                    plot([mu_pp, mu_pp], [0, max(y_pp)], '-', 'Color', col_p_pos, 'LineWidth', 2);
                end

                % --- Plot: Left side (negative y) = P_NEG ---
                if has_pn
                    fill([x_pn, fliplr(x_pn)], [-y_pn, zeros(1, length(y_pn))], ...
                        col_p_neg, 'FaceAlpha', 0.4, 'EdgeColor', col_p_neg, 'LineWidth', 1.5);
                    plot([mu_pn, mu_pn], [0, -max(y_pn)], '-', 'Color', col_p_neg, 'LineWidth', 2);
                end

                % --- Plot: NP as reference on both sides ---
                if has_np
                    plot(x_np, y_np, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    plot(x_np, -y_np, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    % NP mean lines
                    plot([mu_np, mu_np], [0, max(y_np)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
                    plot([mu_np, mu_np], [0, -max(y_np)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
                end

                % --- Zero line and target ---
                % --- Target zone shading (±20mm around target center) ---
                yl_curr = ylim;
                fill([targ_val - 20, targ_val + 20, targ_val + 20, targ_val - 20], ...
                    [yl_curr(1), yl_curr(1), yl_curr(2), yl_curr(2)], ...
                    'r', 'FaceAlpha', 0.05, 'EdgeColor', 'none', 'HandleVisibility', 'off');

                xline(targ_val, 'r:', 'LineWidth', 1);
                yline(0, 'k-', 'LineWidth', 0.5);

                % --- Format y-axis: show absolute values ---
                %ylim([-0.17, 0.17])
                yt = yticks;
                yticklabels(num2str(abs(yt)'));

                xlabel(axis_labels{ax});
                ylabel('Density');
                title(sprintf('T%d', ii), 'FontSize', 11);

                % --- Legend (top-right as a subplot) ---
                if row == 1 && col == 3
                    h_leg1 = fill(nan, nan, col_p_pos, 'FaceAlpha', 0.4, 'EdgeColor', col_p_pos);
                    h_leg2 = fill(nan, nan, col_p_neg, 'FaceAlpha', 0.4, 'EdgeColor', col_p_neg);
                    h_leg3 = plot(nan, nan, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
                    h_leg4 = plot(nan, nan, '-', 'Color', col_p_pos, 'LineWidth', 2);
                    h_leg5 = plot(nan, nan, '-', 'Color', col_p_neg, 'LineWidth', 2);
                    h_leg6 = plot(nan, nan, '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
                    h_leg7 = xline(nan, 'r:', 'LineWidth', 1);
                    lg = legend([h_leg1, h_leg2, h_leg3, h_leg4, h_leg5, h_leg6, h_leg7], ...
                        {[pos_label], [neg_label], 'No-Penalty (ref)', ...
                        [pos_label ' mean'], [neg_label ' mean'], 'NP mean', 'Target'}, ...
                        'FontSize', 5);
                    % Place legend in top-right corner of the figure, outside all subplots
                    lg.Units = 'normalized';
                    lg.Position = [0.915, 0.75, 0.07, 0.15]; % [left, bottom, width, height]
                end
            end
        end

        set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

        if save_fig
            figDir = fullfile(pwd, 'Figures', subID, 'xyz_projection_butterfly');
            if ~exist(figDir, 'dir'), mkdir(figDir); end
            saveas(gcf, fullfile(figDir, sprintf('%s_Axis%s_gaussButterfly.png', subID, axis_names{ax})));
        end

    end %axes
end %plot_singGaussian_butterfly

%% ================= PLOT: ALL AXES GAUSSIAN BUTTERFLY (overlay) =================
if plot_allGaussian_butterfly

    figure('Color', 'w', 'Name', sprintf('%s - All Axes Gaussian Butterfly', subID), ...
        'Position', [50, 50, 1400, 1000]);

    sgtitle(sprintf('fitted Gaussian — %s | All axes | %s (bottom) vs %s (top)', ...
        subID, neg_label, pos_label), ...
        'FontSize', 16, 'FontWeight', 'bold');

    for row = 1:3
        for col = 1:3
            ii = target_order(row, col);
            subplot_idx = (row - 1) * 3 + col;
            subplot(3, 3, subplot_idx);
            hold on;

            for ax = 1:3

                % --- NP: dashed on both sides ---
                if ~isempty(ENDPOINT_NP{ii})
                    mu_c = MU_NP{ii}(ax) - TARGET{ii}(ax);
                    sig_c = sqrt(COV_NP{ii}(ax, ax));
                    x_r = linspace(mu_c - 4*sig_c, mu_c + 4*sig_c, 200);
                    y_r = normpdf(x_r, mu_c, sig_c);
                    plot(x_r, y_r, '--', 'Color', [ax_colors(ax,:), 0.5], 'LineWidth', 1.2);
                    plot(x_r, -y_r, '--', 'Color', [ax_colors(ax,:), 0.5], 'LineWidth', 1.2);
                end

                % --- P_POS: solid on top ---
                if ~isempty(ENDPOINT_P_POS{ii})
                    mu_c = MU_P_POS{ii}(ax) - TARGET{ii}(ax);
                    sig_c = sqrt(COV_P_POS{ii}(ax, ax));
                    x_r = linspace(mu_c - 4*sig_c, mu_c + 4*sig_c, 200);
                    y_r = normpdf(x_r, mu_c, sig_c);
                    plot(x_r, y_r, '-', 'Color', ax_colors(ax,:), 'LineWidth', 2);
                end

                % --- P_NEG: solid on bottom (flipped) ---
                if ~isempty(ENDPOINT_P_NEG{ii})
                    mu_c = MU_P_NEG{ii}(ax) - TARGET{ii}(ax);
                    sig_c = sqrt(COV_P_NEG{ii}(ax, ax));
                    x_r = linspace(mu_c - 4*sig_c, mu_c + 4*sig_c, 200);
                    y_r = normpdf(x_r, mu_c, sig_c);
                    plot(x_r, -y_r, '-', 'Color', ax_colors(ax,:), 'LineWidth', 2);
                end

            end

            % --- Target zone shading ---
            yl_curr = ylim;
            fill([-20, 20, 20, -20], ...
                [yl_curr(1), yl_curr(1), yl_curr(2), yl_curr(2)], ...
                'r', 'FaceAlpha', 0.05, 'EdgeColor', 'none', 'HandleVisibility', 'off');

            xline(0, 'r:', 'LineWidth', 1);
            yline(0, 'k-', 'LineWidth', 0.5);

            yt = yticks;
            yticklabels(num2str(abs(yt)'));

            xlabel('Deviation from target (mm)');
            ylabel('Density');
            title(sprintf('T%d', ii), 'FontSize', 10);

            % --- Legend ---
            if row == 1 && col == 3
                h_x_np  = plot(nan, nan, '--', 'Color', ax_colors(1,:), 'LineWidth', 1.2);
                h_x_pos = plot(nan, nan, '-',  'Color', ax_colors(1,:), 'LineWidth', 2);
                h_y_np  = plot(nan, nan, '--', 'Color', ax_colors(2,:), 'LineWidth', 1.2);
                h_y_pos = plot(nan, nan, '-',  'Color', ax_colors(2,:), 'LineWidth', 2);
                h_z_np  = plot(nan, nan, '--', 'Color', ax_colors(3,:), 'LineWidth', 1.2);
                h_z_pos = plot(nan, nan, '-',  'Color', ax_colors(3,:), 'LineWidth', 2);
                lg = legend([h_x_np, h_x_pos, h_y_np, h_y_pos, h_z_np, h_z_pos], ...
                    {'X (NP)', ['X (P)'], 'Y (NP)', ['Y (P)'], 'Z (NP)', ['Z (P)']}, ...
                    'FontSize', 7);
                lg.Units = 'normalized';
                lg.Position = [0.92, 0.70, 0.07, 0.20];
            end
        end
    end

    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

    if save_fig
        figDir = fullfile(pwd, 'Figures', subID, 'xyz_projection_butterfly');
        if ~exist(figDir, 'dir'), mkdir(figDir); end
        saveas(gcf, fullfile(figDir, sprintf('%s_AllAxes_gaussButterfly.png', subID)));
    end

end %plot_allGaussian_butterfly

close all;


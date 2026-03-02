% ----------------------------------------------------------------------
% project_to_optimal_shift_3D.m
% Project actual endpoint data onto 3D ideal observer's optimal shift
% direction, and compare penalty vs no-penalty conditions.
% ----------------------------------------------------------------------
% Notes:
% For each target and penalty condition:
%   1. Load the 3D optimal shift vector
%   2. Normalize it to a unit vector (the "optimal direction")
%   3. Project each endpoint's deviation from target center onto this
%       vector
%   4. Compare NP vs P distributions along this projection axis
%
% If the subject behaves like the ideal observer, the P distribution
% should shift by approximately |optimal_shift| along this direction.
% ----------------------------------------------------------------------
% Input(s):
%   *_ideal_observer_3D_results.mat
%   *_processed_data.mat
% ----------------------------------------------------------------------
% Output(s):
%   figures
%   .mat
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last update : 2026-03-02
% Last edited by : Rachel Chen
% Project : VR
% Version : 2.0
% ----------------------------------------------------------------------
clc;

%% ================= SWITCHES =================

save_fig = 1;

%% ================= CONFIGURATIONS =================

col_p  = [86, 102, 158] ./255;      % blue (for single-condition histogram plots)
col_ideal = [125,192,73]./255;      % green (Ideal observer prediction)

n_bins = 30;


% ================= LOAD 3D IDEAL OBSERVER RESULTS =================

dataDir_3d_model = fullfile(pwd,'Results', subID,'Model_3D');
matFileName = fullfile(dataDir_3d_model, [subID,'_optimal_observer_3D_results.mat']);

if exist(matFileName, 'file')
    load(matFileName, 'results');
else
    error('No file found for: %s', matFileName);
end

opt_shift_3d = results.opt_shift_3d;   % n_target x n_penalty_cond x 3
penalty_labels = results.penalty_labels;
penalty_conditions = results.penalty_conditions;
n_penalty_cond = size(penalty_conditions, 1);

% ================= LOAD BEHAVIORAL DATA =================
dataDir = fullfile(pwd, 'processedData','splitPenalty');
matFileName = fullfile(dataDir, [subID, '_processed_data_disPenDirec.mat']);

if exist(matFileName, 'file')
    load(matFileName, 'ENDPOINT_NP', 'MU_NP', 'COV_NP', ...
        'ENDPOINT_P_NEG', 'MU_P_NEG', 'COV_P_NEG', ...
        'ENDPOINT_P_POS', 'MU_P_POS', 'COV_P_POS', ...
        'TARGET', 'neg_label', 'pos_label');
else
    error('No file found for: %s', matFileName);
end

% Map penalty conditions to split data:
% penalty_labels from ideal observer results should match neg/pos labels
% Build a lookup: for each penalty condition, which ENDPOINT_P to use
ENDPOINT_P_SPLIT = cell(1, n_penalty_cond);
MU_P_SPLIT = cell(1, n_penalty_cond);
for pp = 1:n_penalty_cond
    if strcmp(penalty_labels{pp}, neg_label)
        ENDPOINT_P_SPLIT{pp} = ENDPOINT_P_NEG;
        MU_P_SPLIT{pp} = MU_P_NEG;
    elseif strcmp(penalty_labels{pp}, pos_label)
        ENDPOINT_P_SPLIT{pp} = ENDPOINT_P_POS;
        MU_P_SPLIT{pp} = MU_P_POS;
    else
        warning('Penalty label "%s" does not match neg_label or pos_label.', penalty_labels{pp});
    end
end

%% ================= PROJECTION ANALYSIS =================

% holder
proj_results = struct();

for pp = 1:n_penalty_cond

    % ===== PLOT: All 9 targets, one figure per penalty condition =====
    figure('Position', [50, 50, 1800, 1000]);
    sgtitle(sprintf('Projection onto 3D optimal shift — %s | %s', ...
        subID, penalty_labels{pp}), 'FontSize', 16, 'FontWeight', 'bold');

    for row = 1:3
        for col = 1:3
            ii = target_order(row, col);
            subplot_idx = (row - 1) * 3 + col;
            subplot(3, 3, subplot_idx);
            hold on;

            targ = TARGET{ii};

            % Get optimal shift vector for this target and this penalty condition
            shift_vec = squeeze(opt_shift_3d(ii, pp, :))';
            shift_mag = norm(shift_vec);

            % Skip if optimal shift is essentially zero
            if shift_mag < 1e-6
                title(sprintf('T%d — no shift', ii));
                continue;
            end

            % Unit vector along optimal shift direction
            d = shift_vec / shift_mag;

            % ===== Project No-Penalty endpoints (inner product) =====
            has_np = ~isempty(ENDPOINT_NP{ii});
            if has_np
                dev_np = ENDPOINT_NP{ii} - targ;      % deviation from target center
                proj_np = dev_np * d';                  % project onto optimal direction
                mu_proj_np = mean(proj_np);

                histogram(proj_np, n_bins, 'Normalization', 'pdf', ...
                    'FaceColor', col_np, 'FaceAlpha', 0.6, 'EdgeColor', 'w');
            end

            % ===== Project Penalty endpoints (inner product) =====
            has_p = ~isempty(ENDPOINT_P_SPLIT{pp}{ii});
            if has_p
                dev_p = ENDPOINT_P_SPLIT{pp}{ii} - targ;
                proj_p = dev_p * d';
                mu_proj_p = mean(proj_p);

                histogram(proj_p, n_bins, 'Normalization', 'pdf', ...
                    'FaceColor', col_p, 'FaceAlpha', 0.6, 'EdgeColor', 'w');
            end

            % ===== Mark means and ideal prediction =====
            yl = ylim;

            if has_np
                plot([mu_proj_np, mu_proj_np], yl, '-', 'Color', col_np, 'LineWidth', 2);
            end
            if has_p
                plot([mu_proj_p, mu_proj_p], yl, '-', 'Color', col_p, 'LineWidth', 2);
            end

            % Ideal observer prediction: shift_mag along this direction
            plot([shift_mag, shift_mag], yl, '--', 'Color', col_ideal, 'LineWidth', 2);

            % Zero line (target center)
            xline(0, 'r:', 'LineWidth', 1); % projection of target center to any direction is zero

            xlabel('Projection (mm)');
            ylabel('Density');

            % Title with stats
            if has_np && has_p
                % --- t-test ---
                [~, p_val] = ttest2(proj_np, proj_p);
                actual_shift = mu_proj_p - mu_proj_np; % bias got canceled out

                title(sprintf('T%d  actual penalty shift=%.1f  ideal=%.1f  p=%.3f', ...
                    ii, actual_shift, shift_mag, p_val), 'FontSize', 9);

                % Store results
                proj_results(ii, pp).target = ii;
                proj_results(ii, pp).penalty = penalty_labels{pp};
                proj_results(ii, pp).optimal_shift_vec = shift_vec;
                proj_results(ii, pp).optimal_shift_mag = shift_mag;
                proj_results(ii, pp).proj_np = proj_np;
                proj_results(ii, pp).proj_p = proj_p;
                proj_results(ii, pp).mu_proj_np = mu_proj_np;
                proj_results(ii, pp).mu_proj_p = mu_proj_p;
                proj_results(ii, pp).actual_shift = actual_shift;
                proj_results(ii, pp).p_val = p_val;
            else
                title(sprintf('T%d  ideal=%.1f', ii, shift_mag), 'FontSize', 9);
            end

            % Legend (top-right subplot only)
            if row == 1 && col == 3
                legend({'NP endpoints', 'P endpoints', 'NP mean', 'P mean', ...
                    'Ideal shift', 'Target center'}, ...
                    'Location', 'northeast', 'FontSize', 7);
            end

        end
    end

    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 11);

    if save_fig
        figDir_3D = fullfile(pwd, 'Figures',subID, 'Model_3D','3D_projection');
        if ~exist(figDir_3D, 'dir'), mkdir(figDir_3D); end
        saveas(gcf, fullfile(figDir_3D, sprintf('%s_3D_projection_%s_hist.png', subID, penalty_labels{pp})));
    end

end % penalty condition loop

%% ===== PLOT: HISTOGRAM BUTTERFLY (both penalty conditions mirrored) =====
% Top = P_POS (pp that matches pos_label)
% Bottom = P_NEG (pp that matches neg_label)
% NP as dashed reference on both sides

figure('Color', 'w', 'Position', [50, 50, 1400, 1000]);
sgtitle(sprintf('Projection to 3D Optimal Shift Histogram — %s | %s (bottom) vs %s (top)', ...
    subID, neg_label, pos_label), 'FontSize', 16, 'FontWeight', 'bold');

% Find which pp index
pp_neg = []; pp_pos = [];
for pp = 1:n_penalty_cond
    if strcmp(penalty_labels{pp}, neg_label), pp_neg = pp; end
    if strcmp(penalty_labels{pp}, pos_label), pp_pos = pp; end
end

for row = 1:3
    for col = 1:3
        ii = target_order(row, col);
        subplot_idx = (row - 1) * 3 + col;
        subplot(3, 3, subplot_idx);
        hold on;

        targ = TARGET{ii};

        % --- Shared bin edges from all projected data ---
        all_proj = [];

        % NP projection (use pp_pos direction as reference, both have same NP)
        shift_vec_pos = squeeze(opt_shift_3d(ii, pp_pos, :))';
        shift_mag_pos = norm(shift_vec_pos);
        shift_vec_neg = squeeze(opt_shift_3d(ii, pp_neg, :))';
        shift_mag_neg = norm(shift_vec_neg);

        if shift_mag_pos < 1e-6 && shift_mag_neg < 1e-6
            title(sprintf('T%d — no shift', ii));
            continue;
        end

        d_pos = shift_vec_pos / shift_mag_pos;
        d_neg = shift_vec_neg / shift_mag_neg;

        % Project NP onto pos direction (for top side reference)
        has_np = ~isempty(ENDPOINT_NP{ii});
        if has_np
            dev_np = ENDPOINT_NP{ii} - targ;
            proj_np_pos = dev_np * d_pos';
            proj_np_neg = dev_np * d_neg';
            all_proj = [all_proj; proj_np_pos; proj_np_neg];
        end

        % Project P_POS onto pos direction
        has_pp = ~isempty(ENDPOINT_P_SPLIT{pp_pos}{ii});
        if has_pp
            dev_pp = ENDPOINT_P_SPLIT{pp_pos}{ii} - targ;
            proj_pp = dev_pp * d_pos';
            all_proj = [all_proj; proj_pp];
        end

        % Project P_NEG onto neg direction
        has_pn = ~isempty(ENDPOINT_P_SPLIT{pp_neg}{ii});
        if has_pn
            dev_pn = ENDPOINT_P_SPLIT{pp_neg}{ii} - targ;
            proj_pn = dev_pn * d_neg';
            all_proj = [all_proj; proj_pn];
        end

        bin_edges = linspace(min(all_proj) - 2, max(all_proj) + 2, n_bins + 1);
        bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;

        % --- P_POS histogram (top) ---
        if has_pp
            [counts_pp, ~] = histcounts(proj_pp, bin_edges, 'Normalization', 'pdf');
            bar(bin_centers, counts_pp, 1, 'FaceColor', col_p_pos, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
        end

        % --- P_NEG histogram (bottom, flipped) ---
        if has_pn
            [counts_pn, ~] = histcounts(proj_pn, bin_edges, 'Normalization', 'pdf');
            bar(bin_centers, -counts_pn, 1, 'FaceColor', col_p_neg, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
        end

        % --- NP outline (both sides) ---
        if has_np
            [counts_np_p, ~] = histcounts(proj_np_pos, bin_edges, 'Normalization', 'pdf');
            [counts_np_n, ~] = histcounts(proj_np_neg, bin_edges, 'Normalization', 'pdf');
            stairs([bin_edges(1), bin_centers, bin_edges(end)], [0, counts_np_p, 0], ...
                '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
            stairs([bin_edges(1), bin_centers, bin_edges(end)], [0, -counts_np_n, 0], ...
                '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
        end

        % --- Ideal shift lines ---
        yl_curr = ylim;
        plot([shift_mag_pos, shift_mag_pos], [0, yl_curr(2)], '--', 'Color', col_ideal, 'LineWidth', 2);
        plot([shift_mag_neg, shift_mag_neg], [yl_curr(1), 0], '--', 'Color', col_ideal, 'LineWidth', 2);

        % --- Zero line ---
        xline(0, 'r:', 'LineWidth', 1);
        yline(0, 'k-', 'LineWidth', 0.5);

        % --- y-axis absolute values ---
        yt = yticks;
        yticklabels(num2str(abs(yt)'));

        xlabel('Projection (mm)');
        ylabel('Density');
        title(sprintf('T%d', ii), 'FontSize', 11);

        % --- Legend ---
        if row == 1 && col == 3
            h_l1 = bar(nan, nan, 'FaceColor', col_p_pos, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
            h_l2 = bar(nan, nan, 'FaceColor', col_p_neg, 'FaceAlpha', 0.5, 'EdgeColor', 'w');
            h_l3 = plot(nan, nan, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
            h_l4 = plot(nan, nan, '--', 'Color', col_ideal, 'LineWidth', 2);
            lg = legend([h_l1, h_l2, h_l3, h_l4], ...
                {[pos_label ' (top)'], [neg_label ' (bottom)'], 'NP (ref)', 'Ideal shift'}, ...
                'FontSize', 5);
            lg.Units = 'normalized';
            lg.Position = [0.91, 0.78, 0.07, 0.12];
        end
    end
end

set(findall(gcf, '-property', 'FontSize'), 'FontSize', 11);

if save_fig
    saveas(gcf, fullfile(figDir_3D, sprintf('%s_3Dproj_hist_butterfly.png', subID)));
end

%% ===== PLOT: GAUSSIAN BUTTERFLY =====

figure('Color', 'w', 'Position', [50, 50, 1400, 1000]);
sgtitle(sprintf('Projection to Optimal Shift: fitted Gaussian — %s | %s (bottom) vs %s (top)', ...
    subID, neg_label, pos_label), 'FontSize', 16, 'FontWeight', 'bold');

for row = 1:3
    for col = 1:3
        ii = target_order(row, col);
        subplot_idx = (row - 1) * 3 + col;
        subplot(3, 3, subplot_idx);
        hold on;

        targ = TARGET{ii};

        % --- Optimal shift vectors ---
        shift_vec_pos = squeeze(opt_shift_3d(ii, pp_pos, :))';
        shift_mag_pos = norm(shift_vec_pos);
        shift_vec_neg = squeeze(opt_shift_3d(ii, pp_neg, :))';
        shift_mag_neg = norm(shift_vec_neg);

        if shift_mag_pos < 1e-6 && shift_mag_neg < 1e-6
            title(sprintf('T%d — no shift', ii));
            continue;
        end

        d_pos = shift_vec_pos / shift_mag_pos;
        d_neg = shift_vec_neg / shift_mag_neg;

        % --- Compute projected distributions ---
        % NP
        has_np = ~isempty(ENDPOINT_NP{ii});
        if has_np
            dev_np = ENDPOINT_NP{ii} - targ;
            proj_np_pos = dev_np * d_pos';
            proj_np_neg = dev_np * d_neg';
            mu_np_pos = mean(proj_np_pos); sig_np_pos = std(proj_np_pos);
            mu_np_neg = mean(proj_np_neg); sig_np_neg = std(proj_np_neg);
        end

        % P_POS
        has_pp = ~isempty(ENDPOINT_P_SPLIT{pp_pos}{ii});
        if has_pp
            proj_pp = (ENDPOINT_P_SPLIT{pp_pos}{ii} - targ) * d_pos';
            mu_pp = mean(proj_pp); sig_pp = std(proj_pp);
        end

        % P_NEG
        has_pn = ~isempty(ENDPOINT_P_SPLIT{pp_neg}{ii});
        if has_pn
            proj_pn = (ENDPOINT_P_SPLIT{pp_neg}{ii} - targ) * d_neg';
            mu_pn = mean(proj_pn); sig_pn = std(proj_pn);
        end

        % --- P_POS Gaussian (top) ---
        if has_pp
            x_r = linspace(mu_pp - 4*sig_pp, mu_pp + 4*sig_pp, 200);
            y_r = normpdf(x_r, mu_pp, sig_pp);
            fill([x_r, fliplr(x_r)], [y_r, zeros(1, length(y_r))], ...
                col_p_pos, 'FaceAlpha', 0.4, 'EdgeColor', col_p_pos, 'LineWidth', 1.5);
            plot([mu_pp, mu_pp], [0, max(y_r)], '-', 'Color', col_p_pos, 'LineWidth', 2);
        end

        % --- P_NEG Gaussian (bottom, flipped) ---
        if has_pn
            x_r = linspace(mu_pn - 4*sig_pn, mu_pn + 4*sig_pn, 200);
            y_r = normpdf(x_r, mu_pn, sig_pn);
            fill([x_r, fliplr(x_r)], [-y_r, zeros(1, length(y_r))], ...
                col_p_neg, 'FaceAlpha', 0.4, 'EdgeColor', col_p_neg, 'LineWidth', 1.5);
            plot([mu_pn, mu_pn], [0, -max(y_r)], '-', 'Color', col_p_neg, 'LineWidth', 2);
        end

        % --- NP reference (both sides) ---
        if has_np
            x_r_p = linspace(mu_np_pos - 4*sig_np_pos, mu_np_pos + 4*sig_np_pos, 200);
            y_r_p = normpdf(x_r_p, mu_np_pos, sig_np_pos);
            plot(x_r_p, y_r_p, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
            plot([mu_np_pos, mu_np_pos], [0, max(y_r_p)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);

            x_r_n = linspace(mu_np_neg - 4*sig_np_neg, mu_np_neg + 4*sig_np_neg, 200);
            y_r_n = normpdf(x_r_n, mu_np_neg, sig_np_neg);
            plot(x_r_n, -y_r_n, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
            plot([mu_np_neg, mu_np_neg], [0, -max(y_r_n)], '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
        end

        % --- Ideal shift lines ---
        yl_curr = ylim;
        plot([shift_mag_pos, shift_mag_pos], [0, yl_curr(2)], '--', 'Color', col_ideal, 'LineWidth', 2);
        plot([shift_mag_neg, shift_mag_neg], [yl_curr(1), 0], '--', 'Color', col_ideal, 'LineWidth', 2);

        % --- Zero line ---
        xline(0, 'r:', 'LineWidth', 2);
        yline(0, 'k-', 'LineWidth', 0.5);

        % --- y-axis absolute values ---
        yt = yticks;
        yticklabels(num2str(abs(yt)'));

        xlabel('Projection (mm)');
        ylabel('Density');
        title(sprintf('T%d', ii), 'FontSize', 11);

        % --- Legend ---
        if row == 1 && col == 3
            h_l1 = fill(nan, nan, col_p_pos, 'FaceAlpha', 0.4, 'EdgeColor', col_p_pos);
            h_l2 = fill(nan, nan, col_p_neg, 'FaceAlpha', 0.4, 'EdgeColor', col_p_neg);
            h_l3 = plot(nan, nan, '--', 'Color', col_np * 0.6, 'LineWidth', 1.5);
            h_l4 = plot(nan, nan, '-', 'Color', col_p_pos, 'LineWidth', 2);
            h_l5 = plot(nan, nan, '-', 'Color', col_p_neg, 'LineWidth', 2);
            h_l6 = plot(nan, nan, '--', 'Color', col_np * 0.5, 'LineWidth', 1.5);
            h_l7 = plot(nan, nan, '--', 'Color', col_ideal, 'LineWidth', 2);
            lg = legend([h_l1, h_l2, h_l3, h_l4, h_l5, h_l6, h_l7], ...
                {pos_label, neg_label, 'NP (ref)', ...
                [pos_label ' mean'], [neg_label ' mean'], 'NP mean', 'Ideal shift'}, ...
                'FontSize', 5);
            lg.Units = 'normalized';
            lg.Position = [0.91, 0.73, 0.07, 0.17];
        end
    end
end

set(findall(gcf, '-property', 'FontSize'), 'FontSize', 11);

if save_fig
    saveas(gcf, fullfile(figDir_3D, sprintf('%s_3Dproj_gaussButterfly.png', subID)));
end

%% ===== PLOT: Summary — actual shift vs ideal shift =====

figure('Position', [100, 100, 800, 400]);
sgtitle(sprintf('Actual vs Ideal Shift (projected) — %s', subID), ...
    'FontSize', 16, 'FontWeight', 'bold');

for pp = 1:n_penalty_cond
    subplot(1, n_penalty_cond, pp); hold on;

    actual_shifts = zeros(n_target, 1);
    ideal_shifts = zeros(n_target, 1);

    for ii = 1:n_target
        if isfield(proj_results, 'actual_shift') && ...
                ii <= size(proj_results, 1) && pp <= size(proj_results, 2) && ...
                ~isempty(proj_results(ii, pp).actual_shift)
            actual_shifts(ii) = proj_results(ii, pp).actual_shift;
            ideal_shifts(ii) = proj_results(ii, pp).optimal_shift_mag;
        end
    end

    % Scatter: ideal vs actual
    scatter(ideal_shifts, actual_shifts, 80, 'filled', 'MarkerFaceColor', col_p);

    for ii = 1:n_target
        text(ideal_shifts(ii) + 0.1, actual_shifts(ii) + 0.1, ...
            sprintf('T%d', ii), 'FontSize', 9);
    end

    % Identity line
    lims = [min([ideal_shifts; actual_shifts]) - 1, max([ideal_shifts; actual_shifts]) + 1];
    plot(lims, lims, 'k--', 'LineWidth', 1);

    % Regression line
    p_line = polyfit(ideal_shifts, actual_shifts,1);
    y_fit = polyval(p_line,lims);
    plot(lims, y_fit, 'Color', 'r', 'LineWidth', 2);

    yticks;
    xlabel('Ideal shift (mm)');
    ylabel('Actual shift (mm)');
    title(penalty_labels{pp});
    grid on;
    axis equal;
end

set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

if save_fig
    saveas(gcf, fullfile(figDir_3D, sprintf('%s_scatter_3D.png', subID)));
end

close all;

%% ===== DISPLAY SUMMARY TABLE =====

fprintf('\n=============== Projection Analysis Results — %s ===============\n', subID);
fprintf('%-8s %-15s %-12s %-12s %-12s %-10s\n', ...
    'Target', 'Penalty', 'Ideal(mm)', 'Actual(mm)', 'Ratio', 'p-value');
fprintf('%s\n', repmat('-', 1, 70));

for pp = 1:n_penalty_cond
    for ii = 1:n_target
        if ~isempty(proj_results(ii, pp).actual_shift)
            ratio = proj_results(ii, pp).actual_shift / proj_results(ii, pp).optimal_shift_mag;
            fprintf('T%-7d %-15s %-12.2f %-12.2f %-12.2f %-10.4f\n', ...
                ii, penalty_labels{pp}, ...
                proj_results(ii, pp).optimal_shift_mag, ...
                proj_results(ii, pp).actual_shift, ...
                ratio, ...
                proj_results(ii, pp).p_val);
        end
    end
end

%% ===== SAVE =====
tableDir = fullfile(pwd, 'Results',subID,'Model_3D');
if ~exist(tableDir, 'dir'), mkdir(tableDir); end

savePath = fullfile(tableDir, sprintf('%s_3D_projection_results.mat', subID));
save(savePath, 'proj_results');
fprintf('\nAll saved!\n');

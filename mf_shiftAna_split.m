% ----------------------------------------------------------------------
% mf_shiftAna_split.m
% Model-free shifty analysis
% How much does aiming shift when there's penalty,
%   and whether this amount differs across 3 axes.
% ----------------------------------------------------------------------
% Notes:
% For each target, !shift is computed as = MU_P - MU_NP for each axis!
%   aiming to reduce the bias
% Aiming to answer:
%   1. Is the shift on each axis significantly different from 0? (one-sample t-test)
%   2. Does |shift| differ across X, Y, Z? (RM ANOVA + post-hoc)
% ----------------------------------------------------------------------
% Input(s):
%   *_processed_data_disPenDirec.mat (from analyze_targets_split.m)
% ----------------------------------------------------------------------
% Output(s):
%   figures
%   console output (stats)
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last update : 2026-02-27
% Project : VR
% Version : 2.0
% ----------------------------------------------------------------------

clc;

baseFigDir = fullfile(pwd, 'Figures', subID);


%% ================= SWITCHES =================
save_fig = 1;

%% ================= CONFIGURATIONS =================

subjectFigFolder = fullfile(baseFigDir, 'mf_shiftAna_split');
if ~exist(subjectFigFolder, 'dir')
    mkdir(subjectFigFolder);
end

%% ================= LOAD DATA =================
matFileName = fullfile(output_process_Dir,[subID '_processed_data_disPenDirec.mat']);

if exist(matFileName, 'file')
    load(matFileName, 'ENDPOINT_NP', 'MU_NP', ...
        'ENDPOINT_P_NEG', 'MU_P_NEG', ...
        'ENDPOINT_P_POS', 'MU_P_POS', ...
        'TARGET', 'neg_label', 'pos_label');
else
    error('No file found for: %s', matFileName);
end

%% ================= COMPUTE SHIFT =================
% shift = MU_P - MU_NP for each target, each axis
% Computed separately for each penalty direction

penalty_dirs = {MU_P_NEG, MU_P_POS};
penalty_dir_labels = {neg_label, pos_label};
n_pen_dir = length(penalty_dir_labels);

for pd = 1:n_pen_dir

    MU_P_curr = penalty_dirs{pd};
    pen_dir_label = penalty_dir_labels{pd};

    shift = zeros(n_target, 3);  % 9 x 3 [dx, dy, dz]

    for ii = 1:n_target
        if ~isempty(MU_P_curr{ii}) && ~isempty(MU_NP{ii})
            shift(ii, :) = MU_P_curr{ii} - MU_NP{ii};
        else
            shift(ii, :) = NaN;
        end
    end

    abs_shift = abs(shift);

    %% ================= DESCRIPTIVE STATS =================

    fprintf('\n=============== Model-Free Shift Analysis — %s | %s ===============\n\n', subID, pen_dir_label);

    fprintf('--- Shift (mm) per target ---\n');
    fprintf('%-8s %10s %10s %10s\n', 'Target', 'dX', 'dY', 'dZ');
    fprintf('%s\n', repmat('-', 1, 42));
    for ii = 1:n_target
        fprintf('T%-7d %+10.2f %+10.2f %+10.2f\n', ii, shift(ii,1), shift(ii,2), shift(ii,3));
    end

    fprintf('\n--- Summary (mean ± SD across 9 targets) ---\n');
    for ax = 1:3
        fprintf('  %s: signed = %+.2f ± %.2f mm, |shift| = %.2f ± %.2f mm\n', ...
            axis_names{ax}, mean(shift(:,ax)), std(shift(:,ax)), ...
            mean(abs_shift(:,ax)), std(abs_shift(:,ax)));
    end

    %% ================= TEST 1: One-sample t-test per axis =================

    fprintf('\n--- One-sample t-test: shift ≠ 0? ---\n');
    fprintf('%-6s %10s %10s %10s %10s\n', 'Axis', 'mean', 'SD', 't-stat', 'p-value');
    fprintf('%s\n', repmat('-', 1, 50));

    p_ttest = zeros(1, 3);
    for ax = 1:3
        [h, p, ci, stats] = ttest(shift(:, ax));
        p_ttest(ax) = p;
        fprintf('%-6s %+10.2f %10.2f %10.2f %10.4f %s\n', ...
            axis_names{ax}, mean(shift(:,ax)), std(shift(:,ax)), ...
            stats.tstat, p, sig_stars(p));
    end

    %% ================= TEST 2: RM ANOVA on |SHIFT| =================

    fprintf('\n--- Repeated-measures ANOVA: |shift| across axes ---\n');

    tbl = table(abs_shift(:,1), abs_shift(:,2), abs_shift(:,3), ...
        'VariableNames', {'X', 'Y', 'Z'});

    within = table(categorical(axis_names'), 'VariableNames', {'Axis'});
    rm = fitrm(tbl, 'X-Z ~ 1', 'WithinDesign', within);
    ranova_result = ranova(rm);

    fprintf('  F(%d,%d) = %.2f, p = %.4f\n', ...
        ranova_result.DF(1), ranova_result.DF(2), ...
        ranova_result.F(1), ranova_result.pValue(1));

    mauchly_tbl = mauchly(rm);
    fprintf('  Mauchly test for sphericity: p = %.4f\n', mauchly_tbl.pValue);

    if ranova_result.pValue(1) < 0.05
        fprintf('  ANOVA significant — running post-hoc pairwise comparisons\n\n');
    else
        fprintf('  ANOVA not significant\n\n');
    end

    %% ================= TEST 3: POST-HOC PAIRWISE COMPARISONS =================

    fprintf('--- Post-hoc: paired t-tests on |shift| (Bonferroni corrected) ---\n');
    fprintf('%-10s %10s %10s %10s %12s\n', 'Pair', 't-stat', 'p (raw)', 'p (corr)', 'Sig');
    fprintf('%s\n', repmat('-', 1, 55));

    pairs = {[1,2], [1,3], [2,3]};
    pair_labels = {'X vs Y', 'X vs Z', 'Y vs Z'};

    allAxes = length(axis_names);
    n_comparisons = (allAxes*(allAxes-1))/2;

    for pp = 1:n_comparisons
        a1 = pairs{pp}(1);
        a2 = pairs{pp}(2);
        [~, p_raw, ~, stats] = ttest(abs_shift(:, a1), abs_shift(:, a2));
        p_corr = min(p_raw * n_comparisons, 1);  % Bonferroni
        fprintf('%-10s %10.2f %10.4f %10.4f %12s\n', ...
            pair_labels{pp}, stats.tstat, p_raw, p_corr, sig_stars(p_corr));
    end

    %% ================= PLOT 1: SHIFT (WITH SIGNS) PER AXIS =================

    figure('Position', [100, 100, 900, 400]);
    sgtitle(sprintf('Aiming Shifts (across targets) by Axis — %s | %s', subID, pen_dir_label), ...
        'FontSize', 16, 'FontWeight', 'bold');

    % Signed shift
    subplot(1, 2, 1); hold on;
    bar_means = mean(shift);
    bar_sems = std(shift) / sqrt(n_target);

    for ax = 1:3
        bar(ax, bar_means(ax), 'FaceColor', ax_colors(ax,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    end
    errorbar(1:3, bar_means, bar_sems, 'k.', 'LineWidth', 1.5, 'MarkerSize', 1);

    for ax = 1:3
        scatter(repmat(ax, n_target, 1) + 0.15*(rand(n_target,1)-0.5), shift(:,ax), ...
            30, ax_colors(ax,:), 'filled', 'MarkerFaceAlpha', 0.5);
    end

    yline(0, 'k--');
    set(gca, 'XTick', 1:3, 'XTickLabel', axis_names);
    xlabel('Axis'); ylabel('Shifts (with sign) (mm)');
    title('Shifts across targets (Penalty - No-Penalty)');
    grid on;

    % Absolute value of the shift
    subplot(1, 2, 2); hold on;
    bar_means_abs = mean(abs_shift);
    bar_sems_abs = std(abs_shift) / sqrt(n_target);

    for ax = 1:3
        bar(ax, bar_means_abs(ax), 'FaceColor', ax_colors(ax,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    end
    errorbar(1:3, bar_means_abs, bar_sems_abs, 'k.', 'LineWidth', 1.5, 'MarkerSize', 1);

    for ax = 1:3
        scatter(repmat(ax, n_target, 1) + 0.15*(rand(n_target,1)-0.5), abs_shift(:,ax), ...
            30, ax_colors(ax,:), 'filled', 'MarkerFaceAlpha', 0.5);
    end

    set(gca, 'XTick', 1:3, 'XTickLabel', axis_names);
    xlabel('Axis'); ylabel('|Shift| (mm)');
    title('Absolute value of Shifts');
    grid on;

    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

    if save_fig
        saveFileName_2 = sprintf('%s_shift_by_axis_%s.png', subID, pen_dir_label);
        fullSavePath = fullfile(subjectFigFolder, saveFileName_2);
        saveas(gcf, fullSavePath);
    end

    %% ================= PLOT 2: Per-target shift heatmap =================

    figure('Position', [100, 100, 600, 500]);

    imagesc(shift);
    colormap(redblue(256));
    max_val = max(abs(shift(:)));
    caxis([-max_val, max_val]);
    cb = colorbar;
    cb.Label.String = 'Shift (mm)';

    set(gca, 'XTick', 1:3, 'XTickLabel', axis_names);
    set(gca, 'YTick', 1:n_target, 'YTickLabel', arrayfun(@(x) sprintf('T%d',x), 1:n_target, 'UniformOutput', false));
    xlabel('Axis'); ylabel('Target');
    title(sprintf('Aiming Shifts Heatmap (P - NP) — %s | %s', subID, pen_dir_label), 'FontSize', 14);

    for ii = 1:n_target
        for ax = 1:3
            if abs(shift(ii, ax)) > max_val * 0.5
                txt_color = 'w';
            else
                txt_color = 'k';
            end
            text(ax, ii, sprintf('%.1f', shift(ii, ax)), ...
                'HorizontalAlignment', 'center', 'Color', txt_color, 'FontSize', 10);
        end
    end

    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);

    if save_fig
        saveFileName = sprintf('%s_shift_heatmap_%s.png', subID, pen_dir_label);
        fullSavePath = fullfile(subjectFigFolder, saveFileName);
        saveas(gcf, fullSavePath);
    end

    close all;

end % penalty direction loop

%% ================= HELPER FUNCTIONS =================

function s = sig_stars(p)
if p < 0.001
    s = '***';
elseif p < 0.01
    s = '**';
elseif p < 0.05
    s = '*';
else
    s = 'n.s.';
end
end

function c = redblue(n)
% Red-white-blue diverging colormap
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0, 1, half), ones(1, n - half)];
g = [linspace(0, 1, half), linspace(1, 0, n - half)];
b = [ones(1, half), linspace(1, 0, n - half)];
c = [r', g', b'];
end

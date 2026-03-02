% ----------------------------------------------------------------------
% EP_3D.m
% 3-panel subplot visualization per target (with penalty region shaded):
%   Left:   All 3 conditions (NP, P_NEG, P_POS)
%   Middle: NP + P_POS only
%   Right:  NP + P_NEG only
% ----------------------------------------------------------------------
% Input(s) :
% *_processed_data_disPenDirec.mat from analyze_targets_split.m 
% ----------------------------------------------------------------------
% Output(s):
% 3D figures
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last update : 2026-02-27
% Last edited by : Rachel Chen
% Project : VR
% Version : 3.0

clc;

%% ================= SWITCHES =================
save_fig = 1;          

%% ================= CONFIGURATIONS =================
col_penalty_shade = [1, 0.3, 0.3]; % not that red for penalty region

t_radius = 10;         % mm (not actual radius, just for schematic reason)
ellipsoid_k = 2;
ellipsoid_alpha = 0.15; 
axis_line_k = 2;

%% ================= MAIN SCRIPT =================

    matFileName = fullfile(output_process_Dir, [subID '_processed_data_disPenDirec.mat']);

    if exist(matFileName, 'file')
        load(matFileName, 'ENDPOINT_NP', 'MU_NP', 'COV_NP', ...
                          'ENDPOINT_P_NEG', 'MU_P_NEG', 'COV_P_NEG', ...
                          'ENDPOINT_P_POS', 'MU_P_POS', 'COV_P_POS', ...
                          'TARGET', 'penalty_axis_tested', ...
                          'neg_label', 'pos_label');
    else
        error('No file found for: %s', matFileName);
    end

    %% ================= PLOTTING =================
    for ii = 1:n_target
        targ_abs = TARGET{ii};

        % --- Collect all points for axis limits ---
        current_targ_pts = [];
        if ~isempty(ENDPOINT_NP{ii}),    current_targ_pts = [current_targ_pts; ENDPOINT_NP{ii} - targ_abs]; end
        if ~isempty(ENDPOINT_P_NEG{ii}), current_targ_pts = [current_targ_pts; ENDPOINT_P_NEG{ii} - targ_abs]; end
        if ~isempty(ENDPOINT_P_POS{ii}), current_targ_pts = [current_targ_pts; ENDPOINT_P_POS{ii} - targ_abs]; end
        
        if isempty(current_targ_pts), continue; end
        
        margin = 10; 
        local_max = max(max(abs(current_targ_pts), [], 1), [25 25 25]) + margin; 
        rel_lim_x = [-local_max(1), local_max(1)];
        rel_lim_y = [-local_max(2), local_max(2)];
        rel_lim_z = [-local_max(3), local_max(3)];

        fig = figure('Color', 'w', 'Position', [50, 50, 2200, 700]);
        sgtitle(sprintf('%s — Target %d (relative to target center)', subID, ii), ...
            'FontSize', 16, 'FontWeight', 'bold');

        % =============================================================
        % SUBPLOT 1: All 3 conditions
        % =============================================================
        ax1 = subplot(1, 3, 1);
        hold on; grid on; axis equal;
        leg_h = []; leg_str = {};

        % NP
        if ~isempty(ENDPOINT_NP{ii})
            data_rel = ENDPOINT_NP{ii} - targ_abs;
            mu_rel = MU_NP{ii} - targ_abs;
            s1 = scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_np, 'x', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            % Projections
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_np, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_np, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_np, '.');
            draw_ellipsoid(mu_rel, COV_NP{ii}, col_np, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_np);
            draw_principal_axes(mu_rel, COV_NP{ii}, col_np, axis_line_k);
            leg_h = [leg_h, s1]; leg_str = [leg_str, {'No-Penalty'}];
        end

        % P_NEG
        if ~isempty(ENDPOINT_P_NEG{ii})
            data_rel = ENDPOINT_P_NEG{ii} - targ_abs;
            mu_rel = MU_P_NEG{ii} - targ_abs;
            s2 = scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_p_neg, '*', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_p_neg, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_p_neg, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_p_neg, '.');
            draw_ellipsoid(mu_rel, COV_P_NEG{ii}, col_p_neg, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_p_neg);
            draw_principal_axes(mu_rel, COV_P_NEG{ii}, col_p_neg, axis_line_k);
            leg_h = [leg_h, s2]; leg_str = [leg_str, {neg_label}];
        end

        % P_POS
        if ~isempty(ENDPOINT_P_POS{ii})
            data_rel = ENDPOINT_P_POS{ii} - targ_abs;
            mu_rel = MU_P_POS{ii} - targ_abs;
            s3 = scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_p_pos, '*', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_p_pos, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_p_pos, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_p_pos, '.');
            draw_ellipsoid(mu_rel, COV_P_POS{ii}, col_p_pos, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_p_pos);
            draw_principal_axes(mu_rel, COV_P_POS{ii}, col_p_pos, axis_line_k);
            leg_h = [leg_h, s3]; leg_str = [leg_str, {pos_label}];
        end

        draw_target_sphere(t_radius);
        draw_ground(rel_lim_x, rel_lim_y, rel_lim_z);
        setup_axes(rel_lim_x, rel_lim_y, rel_lim_z);
        title('All conditions');
        if ~isempty(leg_h), legend(leg_h, leg_str, 'Location', 'northeast', 'FontSize', 8); end

        % =============================================================
        % SUBPLOT 2: NP + P_POS (e.g., Right penalty)
        % =============================================================
        ax2 = subplot(1, 3, 2);
        hold on; grid on; axis equal;

        % NP
        if ~isempty(ENDPOINT_NP{ii})
            data_rel = ENDPOINT_NP{ii} - targ_abs;
            mu_rel = MU_NP{ii} - targ_abs;
            scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_np, 'x', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_np, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_np, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_np, '.');
            draw_ellipsoid(mu_rel, COV_NP{ii}, col_np, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_np);
            draw_principal_axes(mu_rel, COV_NP{ii}, col_np, axis_line_k);
        end

        % P_POS
        if ~isempty(ENDPOINT_P_POS{ii})
            data_rel = ENDPOINT_P_POS{ii} - targ_abs;
            mu_rel = MU_P_POS{ii} - targ_abs;
            scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_p_pos, '+', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_p_pos, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_p_pos, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_p_pos, '.');
            draw_ellipsoid(mu_rel, COV_P_POS{ii}, col_p_pos, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_p_pos);
            draw_principal_axes(mu_rel, COV_P_POS{ii}, col_p_pos, axis_line_k);
        end

        draw_target_sphere(t_radius);
        draw_ground(rel_lim_x, rel_lim_y, rel_lim_z);
        draw_penalty_region(penalty_axis_tested, +1, rel_lim_x, rel_lim_y, rel_lim_z, col_penalty_shade);
        setup_axes(rel_lim_x, rel_lim_y, rel_lim_z);
        title(sprintf('No-penalty + Penalty on %s', pos_label));

        % =============================================================
        % SUBPLOT 3: NP + P_NEG (e.g., Left penalty)
        % =============================================================
        ax3 = subplot(1, 3, 3);
        hold on; grid on; axis equal;

        % NP
        if ~isempty(ENDPOINT_NP{ii})
            data_rel = ENDPOINT_NP{ii} - targ_abs;
            mu_rel = MU_NP{ii} - targ_abs;
            scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_np, 'x', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_np, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_np, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_np, '.');
            draw_ellipsoid(mu_rel, COV_NP{ii}, col_np, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_np);
            draw_principal_axes(mu_rel, COV_NP{ii}, col_np, axis_line_k);
        end

        % P_NEG
        if ~isempty(ENDPOINT_P_NEG{ii})
            data_rel = ENDPOINT_P_NEG{ii} - targ_abs;
            mu_rel = MU_P_NEG{ii} - targ_abs;
            scatter3(data_rel(:,1), data_rel(:,2), data_rel(:,3), ...
                80, col_p_neg, '*', 'LineWidth', 1.5, 'MarkerEdgeAlpha', 0.4);
            scatter3(data_rel(:,1), data_rel(:,2), repmat(rel_lim_z(1), size(data_rel,1), 1), 300, col_p_neg, '.');
            scatter3(data_rel(:,1), repmat(rel_lim_y(2), size(data_rel,1), 1), data_rel(:,3), 300, col_p_neg, '.');
            scatter3(repmat(rel_lim_x(1), size(data_rel,1), 1), data_rel(:,2), data_rel(:,3), 300, col_p_neg, '.');
            draw_ellipsoid(mu_rel, COV_P_NEG{ii}, col_p_neg, ellipsoid_alpha, ellipsoid_k);
            draw_ellipsoid_center(mu_rel, col_p_neg);
            draw_principal_axes(mu_rel, COV_P_NEG{ii}, col_p_neg, axis_line_k);
        end

        draw_target_sphere(t_radius);
        draw_ground(rel_lim_x, rel_lim_y, rel_lim_z);
        draw_penalty_region(penalty_axis_tested, -1, rel_lim_x, rel_lim_y, rel_lim_z, col_penalty_shade);
        setup_axes(rel_lim_x, rel_lim_y, rel_lim_z);
        title(sprintf('No-penalty + Penalty on %s', neg_label));

        % ================= Link views for 3 panels =================
        Link = linkprop([ax1, ax2, ax3], {'View', 'XLim', 'YLim', 'ZLim'});
        setappdata(fig, 'StoreTheLink', Link);

        set(findall(gcf, '-property', 'FontSize'), 'FontSize', 11);

        if save_fig
            figDir = fullfile(pwd, 'Figures', subID, 'EP_3D');
            if ~exist(figDir, 'dir'), mkdir(figDir); end
            saveas(gcf, fullfile(figDir, sprintf('%s_T%d_3D.png', subID, ii)));
            savefig(gcf, fullfile(figDir, sprintf('%s_T%d_3D.fig', subID, ii)));
        end
    end 

close all;

%% ================= HELPER FUNCTIONS =================

% --------- Draw ellipsoid   ---------
function draw_ellipsoid(mu, C, col, alpha, k)
    [X, Y, Z] = sphere(30);
    [U, S, ~] = svd(C);
    scaled = k * [X(:), Y(:), Z(:)] * sqrt(S) * U';
    X = reshape(scaled(:,1), size(X)) + mu(1);
    Y = reshape(scaled(:,2), size(Y)) + mu(2);
    Z = reshape(scaled(:,3), size(Z)) + mu(3);
    surf(X, Y, Z, 'FaceColor', col, 'EdgeColor', 'none', 'FaceAlpha', alpha);
    camlight; lighting gouraud;
end

function draw_ellipsoid_center(mu, col)
    r = 0.8;
    [X, Y, Z] = sphere(15);
    surf(X*r + mu(1), Y*r + mu(2), Z*r + mu(3), ...
        'FaceColor', col, 'EdgeColor', 'none', 'FaceAlpha', 0.9, 'HandleVisibility', 'off');
end

function draw_principal_axes(mu, C, col, k)
    [U, S, ~] = svd(C);
    for ax = 1:3
        direction = U(:, ax)';
        half_len = k * sqrt(S(ax, ax));
        pt1 = mu - half_len * direction;
        pt2 = mu + half_len * direction;
        plot3([pt1(1), pt2(1)], [pt1(2), pt2(2)], [pt1(3), pt2(3)], ...
            '-', 'Color', col, 'LineWidth', 2, 'HandleVisibility', 'off');
    end
end

% --------- Draw target   ---------
function draw_target_sphere(t_radius)
    [Xs, Ys, Zs] = sphere(30);
    surf(Xs*t_radius, Ys*t_radius, Zs*t_radius, ...
        'FaceColor', [0.2 0.8 0.2], 'EdgeColor', 'none', 'FaceAlpha', 0.05, ...
        'HandleVisibility', 'off');
    % Center dot
    r = 1;
    [Xb, Yb, Zb] = sphere(15);
    surf(Xb*r, Yb*r, Zb*r, ...
        'FaceColor', 'k', 'EdgeColor', 'none', 'FaceAlpha', 0.1, 'HandleVisibility', 'off');
end

% --------- Make it pretty   ---------
function setup_axes(xl, yl, zl)
    view(45, 20);
    xlim(xl); ylim(yl); zlim(zl);
    xlabel('\Delta X (mm)'); ylabel('\Delta Y (mm)'); zlabel('\Delta Z (mm)');
end

function draw_ground(xl, yl, zl)
% Draw a semi-transparent ground plane at z = zl(1).
    patch([xl(1) xl(2) xl(2) xl(1)], ...
          [yl(1) yl(1) yl(2) yl(2)], ...
          [zl(1) zl(1) zl(1) zl(1)], ...
          'k', 'FaceAlpha', 0.03, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function draw_penalty_region(penalty_axis, penalty_sign, xl, yl, zl, col)
% Draw a semi-transparent shaded box on the penalty side.
% penalty_axis: 1=X, 2=Y, 3=Z
% penalty_sign: +1 = positive side, -1 = negative side
%
% The penalty boundary is at 0 (target center).
% If penalty_sign = +1, shade from 0 to the positive limit.
% If penalty_sign = -1, shade from the negative limit to 0.

    switch penalty_axis
        case 1 % X axis
            if penalty_sign > 0
                verts = [0     yl(1) zl(1);  xl(2) yl(1) zl(1);  xl(2) yl(2) zl(1);  0     yl(2) zl(1); ...
                         0     yl(1) zl(2);  xl(2) yl(1) zl(2);  xl(2) yl(2) zl(2);  0     yl(2) zl(2)];
            else
                verts = [xl(1) yl(1) zl(1);  0     yl(1) zl(1);  0     yl(2) zl(1);  xl(1) yl(2) zl(1); ...
                         xl(1) yl(1) zl(2);  0     yl(1) zl(2);  0     yl(2) zl(2);  xl(1) yl(2) zl(2)];
            end
        case 2 % Y axis
            if penalty_sign > 0
                verts = [xl(1) 0     zl(1);  xl(2) 0     zl(1);  xl(2) yl(2) zl(1);  xl(1) yl(2) zl(1); ...
                         xl(1) 0     zl(2);  xl(2) 0     zl(2);  xl(2) yl(2) zl(2);  xl(1) yl(2) zl(2)];
            else
                verts = [xl(1) yl(1) zl(1);  xl(2) yl(1) zl(1);  xl(2) 0     zl(1);  xl(1) 0     zl(1); ...
                         xl(1) yl(1) zl(2);  xl(2) yl(1) zl(2);  xl(2) 0     zl(2);  xl(1) 0     zl(2)];
            end
        case 3 % Z axis
            if penalty_sign > 0
                verts = [xl(1) yl(1) 0;      xl(2) yl(1) 0;      xl(2) yl(2) 0;      xl(1) yl(2) 0; ...
                         xl(1) yl(1) zl(2);  xl(2) yl(1) zl(2);  xl(2) yl(2) zl(2);  xl(1) yl(2) zl(2)];
            else
                verts = [xl(1) yl(1) zl(1);  xl(2) yl(1) zl(1);  xl(2) yl(2) zl(1);  xl(1) yl(2) zl(1); ...
                         xl(1) yl(1) 0;      xl(2) yl(1) 0;      xl(2) yl(2) 0;      xl(1) yl(2) 0];
            end
    end

    % 6 faces of the box
    faces = [1 2 3 4;    % bottom
             5 6 7 8;    % top
             1 2 6 5;    % front
             3 4 8 7;    % back
             1 4 8 5;    % left
             2 3 7 6];   % right

    patch('Vertices', verts, 'Faces', faces, ...
        'FaceColor', col, 'FaceAlpha', 0.06, ...
        'EdgeColor', col, 'EdgeAlpha', 0.15, 'LineStyle', '--', ...
        'HandleVisibility', 'off');
end

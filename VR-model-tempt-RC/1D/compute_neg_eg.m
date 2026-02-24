function neg_eg = compute_neg_eg(shift, t_center, cov_matrix, ...
    p_axis, p_sign, t_radius, penalty_edge, ...
    value_target, value_penalty, n_samples)

% ----------------------------------------------------------------------
% compute_neg_eg.m
% Compute negative expected gain for a given shift.
% ----------------------------------------------------------------------
% Notes: 
% -
% ----------------------------------------------------------------------
% Input(s) :
%   shift         - scalar, shift along the penalty axis (mm)
%   t_center      - 1x3, target center coordinates, should be [0,0,0]
%   cov_matrix    - 3x3, empirical covariance matrix (mm^2)
%   p_axis        - 1, 2, or 3 (X, Y, or Z)
%   p_sign        - +1 or -1 (left/right)
%   t_radius      - scalar, target sphere radius (mm)
%   penalty_edge  - scalar, distance from target center to penalty edge (mm)
%   value_target  - scalar, value for hitting target
%   value_penalty - scalar, value for hitting penalty
%   n_samples     - scalar, # of MC sampling
% ----------------------------------------------------------------------
% Output(s):
%   neg_eg        - scalar, negative expected gain cuz BADS minimizes
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last update : 2026-02-24
% Project : VR
% Version : 3.0
% ----------------------------------------------------------------------

    aimpoint = t_center;
    aimpoint(p_axis) = t_center(p_axis) + shift;

    % Sampling 3D endpoints
    endpoints = mvnrnd(aimpoint, cov_matrix, n_samples);

    % Hit target: 3D Euclidean distance <= radius
    dist_to_target = sqrt(sum((endpoints - t_center).^2, 2)); % the 3D distance of shifts from the center
    prop_target = mean(dist_to_target <= t_radius); % portion
    % sum(dist_to_target <= t_radius) / n_samples; 

    % Hit penalty
    if p_sign > 0
        prop_penalty = mean(endpoints(:, p_axis) >= t_center(p_axis) + penalty_edge);
    else
        prop_penalty = mean(endpoints(:, p_axis) <= t_center(p_axis) - penalty_edge);
    end

    % EG
    neg_eg = -(prop_target * value_target + prop_penalty * value_penalty);
end

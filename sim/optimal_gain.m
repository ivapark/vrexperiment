function out = optimal_gain(free_param, model)

if strcmp(model.mode, 'initialize')

    out.param_id = {'dx','dy','dz'};
    out.num_param = length(out.param_id);

    % hard bounds, the range for lb, ub, larger than soft bounds
    param_h.dx = [-0.2, 0.2]; % m
    param_h.dy = [-0.2, 0.2]; % m
    param_h.dz = [-0.2, 0.2]; % m

    % soft bounds, the range for plb, pub
    param_s.dx = [-0.1, 0.1]; % m
    param_s.dy = [-0.1, 0.1]; % m
    param_s.dz = [-0.1, 0.1]; % m

    % reorganize parameter bounds to feed to bads
    fields = fieldnames(param_h);
    for k = 1:numel(fields)
        out.lb(:,k) = param_h.(fields{k})(1);
        out.ub(:,k) = param_h.(fields{k})(2);
        out.plb(:,k) = param_s.(fields{k})(1);
        out.pub(:,k) = param_s.(fields{k})(2);
    end
    model.param_s = param_s; 
    model.param_h = param_h;

    % get grid initializations
    num_sections = model.n_run;
    out.init = getInit(out.lb, out.ub, num_sections, model.n_run);

else
    
    % assign free parameters
    dx = free_param(1);
    dy = free_param(2);
    dz = free_param(3);
    target = model.target_coor + [dx, dy, dz];

        % sample endpoints
        endpoint = mvnrnd(target, model.empirical_cov, model.sim_trial);
        
        % for each endpoint, calculate the gain function
        gains = gain_function(model.target_coor, model.penalty_cond, endpoint, model);
        out = nansum(gains);

end

end

function gain = gain_function(target_coor, penalty_cond, endpoint, model)
    % target_coor, penalty_corr, endpoint: n_trial x 3 (X, Y, Z)

    % initialize gain
    gain = zeros(size(endpoint, 1), 1);

    % Add gains for hit trials
    distance_to_target = sqrt(sum((endpoint - target_coor).^2, 2));
    hit_trial = distance_to_target < model.hit_threshold;
    gain(hit_trial) = model.hit_gain;

    % Find the dimension of the penalty of this condition
    penalty_dim = penalty_cond~=0;
    penalty_dim_idx = find(penalty_dim~=0);
    penalty_distance = penalty_cond(penalty_dim);

    if penalty_distance > 0 % e.g., penalty is on the right of the target
        penalty_trial = endpoint(:, penalty_dim_idx) - penalty_distance > 0;
        gain(penalty_trial) = gain(penalty_trial) + model.penalty_gain;

    else % e.g., penalty is on the left of the target
        penalty_trial = endpoint(:, penalty_dim_idx) - penalty_distance < 0;
        gain(penalty_trial) = gain(penalty_trial) + model.penalty_gain;
    end

end
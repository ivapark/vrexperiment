function out = optimal_gain(free_param, model, data)

if strcmp(model.mode, 'initialize')

    out.param_id = {'x','y','z'};
    out.num_param = length(out.param_id);

    % hard bounds, the range for lb, ub, larger than soft bounds
    param_h.x = [-0.2, 0.2]; % m
    param_h.y = [-0.2, 0.2]; % m
    param_h.z = [-0.2, 0.2]; % m

    % soft bounds, the range for plb, pub
    param_s.x = [-0.1, 0.1]; % m
    param_s.y = [-0.1, 0.1]; % m
    param_s.z = [-0.1, 0.1]; % m


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
    x = free_param(1);
    y = free_param(2);
    z = free_param(3);

% sample endpoints
        endpoint_samples = mvnrnd([x, y, z], model.empirical_cov, model.n_trial);
        
        % for each endpoint, calculate the gain function
        
        out = expected_gain;

end

end

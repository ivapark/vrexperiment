clear; close all; clc;

%% manage paths

[project_dir, ~]= fileparts(pwd);
[git_dir, ~] = fileparts(project_dir);
data_dir = fullfile(project_dir, 'data','organized_data');
addpath(genpath(fullfile(git_dir, 'bads'))); % add optimization tool, here we use BADS for example
out_dir = fullfile(pwd, 'optimal'); % output will be saved to the model folder
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% organize data

% Extract real covariance matrix once data is available
sig_x = 0.5; % X and Y have similar smaller variances
sig_y = 0.5;
sig_z = 0.5; % Z has larger variance 
sig_xy = 0;
sig_xz = 0.1;
sig_yz = 0.1;

Sigma = [sig_x, sig_xy, sig_xz;
         sig_xy, sig_y, sig_yz; 
         sig_xz, sig_yz, sig_z];

%% set up model

model.empirical_cov = Sigma;
model.sim_trial = 1000;
model.hit_threshold = 0.05; % m
model.hit_gain = 300;
model.penalty_gain = -500;

%% set up model fitting

model.n_run = 1; % number of fits for each model
options.UncertaintyHandling = true; 

%% load data

load(fullfile(data_dir,'IP_valid_data.mat'));
target_coors = [valid_data.TargetX, valid_data.TargetY, valid_data.TargetZ];
target_conditions = unique(target_coors, 'rows');
penalty_conditions = [-0.5, 0, 0; 0.5, 0, 0; 0, -0.5, 0; 0, 0.5, 0; 0, 0, -0.5; 0, 0, 0.5];

for cc = 1:size(target_conditions,1)

    for pp = 1:size(penalty_conditions,1)
        
        %% condition-specific model setting

        model.target_coor = target_conditions(cc,:);
        model.penalty_cond = penalty_conditions(pp,:);

        %% run
      
        curr_model =  str2func('optimal_gain');

        model.mode = 'initialize';
        val = curr_model([], model);
        model.init_val = val;

        model.mode = 'optimize';
        neg_gain_func = @(x) -curr_model(x, model);
        % fprintf('[%s] Start fitting model-%s\n', mfilename);

        % test = curr_model(val.init(1,:), model);

        % fit the model multiple times with different initial values
        est_p = nan(model.n_run, val.num_param);
        neg_gain = nan(1, model.n_run);
        for i  = 1:model.n_run
            [est_p(i,:), neg_gain(i)] = bads(neg_gain_func,...
                val.init(i,:), val.lb, val.ub, val.plb, val.pub);
        end

        % find the best fits across runs
        [min_neg_gain, best_idx] = min(neg_gain);
        best_p = est_p(best_idx, :);
        fits(cc, pp).est_p = est_p;
        fits(cc, pp).best_p = best_p;
        fits(cc, pp).max_gain = -min_neg_gain;
        % 
        % %% model prediction using the best-fitting parameters
        % 
        % model.mode = 'predict';
        % pred = curr_model(best_p, model, []);

    end
end

%% save full results
fprintf('[%s] Model simulation done! Saving full results.\n', mfilename);
flnm = 'example_results';
save(fullfile(out_dir, flnm),'model','fits');

clear; close all; clc;

%% knobs
i_model=1; % selected model to fit

%% specify models
rng('shuffle');

% --------------------- set your model here -------------------------------
specifications = {'Optimal observer'}; % official model names for plotting
folders = {'optimal'}; % short names for folders
% -------------------------------------------------------------------------

n_model = numel(specifications);
model_info = table((1:n_model)', specifications', folders', 'VariableNames', {'Number', 'Specification', 'FolderName'});

%% manage paths

[project_dir, ~]= fileparts(pwd);
[git_dir, ~] = fileparts(project_dir);
addpath(genpath(fullfile(project_dir, 'data')));
addpath(genpath(fullfile(project_dir, 'utils')));
addpath(genpath(fullfile(git_dir, 'bads'))); % add optimization tool, here we use BADS for example
out_dir = fullfile(pwd, folders{i_model}); % output will be saved to the model folder
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% organize data

% Extract real covariance matrix once data is available
sig_x = 1; % X and Y have similar smaller variances
sig_y = 1;
sig_z = 2; % Z has larger variance 
sig_xy = 0;
sig_xz = -0.1;
sig_yz = 0.1;

Sigma = [sig_x, sig_xy, sig_xz;
         sig_xy, sig_y, sig_yz; 
         sig_xz, sig_yz, sig_z];

%% set up model

model.n_run = 5; % number of fits for each model
model.empirical_cov = Sigma;
model.n_trial = 1000;

%% fit model

fit_str = folders{i_model};
addpath(genpath(fullfile(pwd, fit_str)));
curr_model = str2func([fit_str '_gain']);

model.mode = 'initialize';
val = curr_model([], model, []);
model.init_val = val;

model.mode = 'optimize';
llfun = @(x) curr_model(x, model, i_data);
fprintf('[%s] Start fitting model-%s\n', mfilename, fit_str);

% fit the model multiple times with different initial values
est_p = nan(model.n_run, val.num_param);
nll = nan(1, model.n_run);
for i  = 1:model.n_run
    [est_p(i,:), nll(i)] = bads(llfun,...
        val.init(i,:), val.lb, val.ub, val.plb, val.pub);
end

% find the best fits across runs
[min_nll, best_idx] = min(nll);
best_p = est_p(best_idx, :);
fits(i_sample).best_p = best_p;
fits(i_sample).min_nll = min_nll;

%% model prediction using the best-fitting parameters

model.mode = 'predict';
pred = curr_model(best_p, model, []);

%% save full results
fprintf('[%s] Model simulation done! Saving full results.\n', mfilename);
flnm = 'example_results';
save(fullfile(out_dir, flnm), 'data','model','fits','pred');

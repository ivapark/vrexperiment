clear; close all; clc;


%% manage paths

[project_dir, ~]= fileparts(pwd);
[git_dir, ~] = fileparts(project_dir);
addpath(genpath(fullfile(git_dir, 'bads'))); % add optimization tool, here we use BADS for example
out_dir = fullfile(pwd, mfilename); % output will be saved to folder with the same name
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% set up model

%%%%%%%%%%%%%%%%%%%%%%%%%%% Set up for simulation %%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set covariance matrix. Extract real covariance matrix once data is available
sig_x = 0.01; % m, X and Y have similar smaller variances
sig_y = 0.01;
sig_z = 0.02; % Z has larger variance
sig_xy = 0.005;
sig_xz = 0.005;
sig_yz = 0.005;

Sigma = [sig_x, sig_xy, sig_xz;
    sig_xy, sig_y, sig_yz;
    sig_xz, sig_yz, sig_z];
%%%%%%%%%%%%%%%%%%%%%%%%%%% Set up for simulation %%%%%%%%%%%%%%%%%%%%%%%%%%%

% Adjust experiment parameters accordingly
model.sim_trial = 1e5; % number of simulations of reaches in optimization
model.empirical_cov = Sigma;
model.hit_threshold = 0.003; % m, target radius
model.hit_gain = 0.3;
model.penalty_gain = -0.5;
model.penalty_threshold = 0.003; % m, distance between target center and the edge of the penalty zone

% Used one coordinate, one penalty condition for example
model.target_coor = [-1, 1.1, 2.44];
model.penalty_cond = [-model.penalty_threshold, 0, 0];

%% set up model fitting

model.n_run = 100; % number of fits for each model
options.UncertaintyHandling = true;

%% Simulation start
%% 1. Predict optimal aiming point

curr_model =  str2func('optimal_gain');

model.mode = 'initialize';
val = curr_model([], model);
model.init_val = val;

model.mode = 'optimize';
neg_gain_func = @(x) -curr_model(x, model);

% For debug purpose
% testp = [0.13330078125 0 0.13330078125];
% test = neg_gain_func(testp);

% Fit the model multiple times with different initial values
est_p = nan(model.n_run, val.num_param);
neg_gain = nan(1, model.n_run);
parfor i  = 1:model.n_run
    temp_val = val;
    [est_p(i,:), neg_gain(i)] = bads(neg_gain_func,...
        temp_val.init(i,:), temp_val.lb, temp_val.ub, temp_val.plb, temp_val.pub);
end

% Find the best fits across runs
[min_neg_gain, best_idx] = min(neg_gain);
best_p = est_p(best_idx, :);
fits.param_info = val;
fits.est_p = est_p;
fits.best_p = best_p;
fits.max_gain = -min_neg_gain;

% Check histogram of parameter estimates
% figure;
% for pp = 1:3
% subplot(1,3,pp)
%     histogram(est_p(:,pp))
%     xline(best_p(pp),'r')
% end

%% 2. Simulate sample mean difference between penalty and no penalty conditions

%%%%%%%%%%%%%%%%%%%%%%%%%%% Set up for simulation %%%%%%%%%%%%%%%%%%%%%%%%%%%
sim_ntrial = 10000; % number of simulation (i.e., participants)
p_ntrials = 20:20:80; % numbers of trials of penalty condition
np_ntrials = 60:20:160; % numbers of trials of no-penalty condition
%%%%%%%%%%%%%%%%%%%%%%%%%%% Set up for simulation %%%%%%%%%%%%%%%%%%%%%%%%%%%
opt_aim = model.target_coor + best_p;

sample_mean_diff = nan(length(p_ntrials), length(np_ntrials), sim_ntrial); 
CI_95 = nan(length(p_ntrials), length(np_ntrials), 2);
for mm = 1:length(p_ntrials)
    model.penalty_ntrial = p_ntrials(mm);

    for nn = 1:length(np_ntrials)
        model.no_penalty_ntrial = np_ntrials(nn);

        parfor tt = 1:sim_ntrial
            M = model;

            % Simulate endpoints of penalty condition
            ep_nopenalty = mvnrnd(M.target_coor, M.empirical_cov, M.penalty_ntrial);

            % Simulate endpoints of no penalty condition
            ep_penalty = mvnrnd(opt_aim, M.empirical_cov, M.no_penalty_ntrial);

            % Calculate sample mean euclidean distance difference
            sample_mean_diff(mm,nn,tt) = sqrt(sum((mean(ep_penalty, 1) - mean(ep_nopenalty, 1)).^2));
        end

        % Calculate 95% confidence interval
        CI_95(mm, nn, :) = prctile(sample_mean_diff(mm,nn,:), [2.5, 97.5]);
        
    end
end

%% 3. Plot histogram of sample mean difference with 95% CI


% Use the same x and y limits for all subplots
all_sample_mean_diff = sample_mean_diff(:);
edges = linspace(min(all_sample_mean_diff), max(all_sample_mean_diff), 100);
xmin = min(0, min(all_sample_mean_diff));
xmax = max(max(all_sample_mean_diff),0);


% Compute the maximum y-limit across all histograms
ymax = 0;
for mm = 1:numel(p_ntrials)
    for nn = 1:numel(np_ntrials)
        h = histogram(squeeze(sample_mean_diff(mm, nn, :)), edges, 'Visible', 'off');
        ymax = max(ymax, max(h.Values));
        delete(h);
    end
end

figure;
set(gcf, 'Position', get(0, 'Screensize'));
tiledlayout(numel(p_ntrials), numel(np_ntrials)); % Penalty x no penalty

for mm = 1:numel(p_ntrials)
    for nn = 1:numel(np_ntrials)
        nexttile;
        h = histogram(squeeze(sample_mean_diff(mm, nn, :)), edges);
        h.EdgeColor = 'none';
        xlim([xmin xmax]);
        ylim([0 ymax]);
        title({sprintf('#trials in penalty: %d', p_ntrials(mm)), sprintf('#trials in no penalty: %d', np_ntrials(nn))});

        % add CI 95%
        if mm == 1 && nn ==1
            xline(squeeze(CI_95(mm, nn, 1)), 'k-', 'lineWidth',1.5,'label','95% CI');
            xline(squeeze(CI_95(mm, nn, 2)), 'k-', 'lineWidth',1.5,'handleVisibility','off');
            xline(0, 'r--','lineWidth',1.5,'label', 'No difference');
            xlabel('Sample mean L2 difference (m)');
            ylabel('Frequency');
            
        else
            xline(squeeze(CI_95(mm, nn, 1)), 'k-', 'lineWidth',1.5,'handleVisibility','off');
            xline(squeeze(CI_95(mm, nn, 2)), 'k-', 'lineWidth',1.5,'handleVisibility','off');
            xline(0, 'r--','lineWidth',1.5,'handleVisibility','off');
        end
    end

end

saveas(gcf, fullfile(out_dir, sprintf('predict_ntrials_%d_%d.png', p_ntrials(end), np_ntrials(end))));


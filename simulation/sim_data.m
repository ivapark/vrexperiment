clear; close all;

%% Sample reach endpoints in the practice session

% use the starting point as the origin [0,0,0]
% x: left (negative) - right (positive)
% y: up (positive) - down (negative)
% z: forward (positive) - backward (negative)
% use the middle target as an example
exp_info.target = [0, 0, 5];

% define covariance matrix for endpoint distribution
% in reality, the covariance matrix is not known, but we can use the empirical covariance matrix from the practice session
sig_x = 1; % X and Y have similar smaller variances
sig_y = 1;
sig_z = 2; % Z has larger variance 
sig_xy = 0;
sig_xz = -0.1;
sig_yz = 0.1;

Sigma = [sig_x, sig_xy, sig_xz;
         sig_xy, sig_y, sig_yz; 
         sig_xz, sig_yz, sig_z];

% number of trials in the practice session
n_trial = 1000;

% sample endpoints
e_practice = mvnrnd(exp_info.target, Sigma, n_trial);

% plot endpoints
figure;
scatter3(e_practice(:,1), e_practice(:,2), e_practice(:,3), 'filled');
hold on;
t = plot3(exp_info.target(1), exp_info.target(2), exp_info.target(3), 'rx', 'MarkerSize', 15, 'LineWidth', 3);

title('Sample endpoints in the practice session')
xlabel('X (cm)');
ylabel('Y (cm)');
zlabel('Z (cm)');
legend(t, 'Target');

%% Sample endpoints with a penalty zone assuming an optimal-observer model

% radius of the target sphere (cm)
exp_info.t_radius = 1;

% example: a left penalty zone from infinity (-x_bound) to -2 (x_penalty) cm
exp_info.x_bound = 20;
exp_info.x_penalty = -2; 

% number of trials with a penalty zone
exp_info.n_penalty_trial = 1000;

% sample endpoints with a penalty zone
model_sim = optimal_observer_model(exp_info, e_practice, []);

% plot the endpoint distribution from both conditions
figure;
view(3);
hold on;

% practice session ellipsoid (95% confidence)
[x,y,z] = ellipsoid(exp_info.target(1), exp_info.target(2), exp_info.target(3), ...
                    2*sqrt(Sigma(1,1)), 2*sqrt(Sigma(2,2)), 2*sqrt(Sigma(3,3)), 50);
practice_ellipsoid = surf(x, y, z, 'FaceColor', 'blue', 'FaceAlpha', 0.1, ...
                         'EdgeColor', 'none');

% penalty condition ellipsoid (95% confidence)
[x,y,z] = ellipsoid(model_sim.target(1), model_sim.target(2), model_sim.target(3), ...
                    2*sqrt(model_sim.cov(1,1)), 2*sqrt(model_sim.cov(2,2)), ...
                    2*sqrt(model_sim.cov(3,3)), 50);
penalty_ellipsoid = surf(x, y, z, 'FaceColor', 'red', 'FaceAlpha', 0.1, ...
                        'EdgeColor', 'none');

xlabel('X (cm)');
ylabel('Y (cm)');
zlabel('Z (cm)');
title('Endpoint distribution');
legend([practice_ellipsoid, penalty_ellipsoid], {'Practice condition', 'Penalty condition'});
grid on;

%% TO-DO 1: fit the same model to the fake penalty data


%% TO-DO 2: revise optimal_observer_model such that it works for all targets and all penalty zones


%% optimal-observer model

function out = optimal_observer_model(exp_info, practice_data, penalty_data)

% summarize practice data
empirical_mu_x = mean(practice_data(:,1)); % 1 corresponds to x-axis
empirical_sig_x = std(practice_data(:,1));

% define an axis
x_axis = linspace(-exp_info.x_bound, exp_info.x_bound, 100);
x_pdf = normpdf(x_axis, empirical_mu_x, empirical_sig_x);

% define gain function
gain = zeros(size(x_axis));

% points within target radius get +1 score
target_idx = (x_axis >= exp_info.target(1) - exp_info.t_radius) & ...
             (x_axis <= exp_info.target(1) + exp_info.t_radius);
gain(target_idx) = 1;

% points in penalty region get -5 score
penalty_idx = x_axis < exp_info.x_penalty;
gain(penalty_idx) = -5;

% expected gain function
expected_gain = gain .* x_pdf;

% optional: plot to check
% figure;
% hold on;
% plot(x_axis, x_pdf);
% plot(x_axis, gain);
% plot(x_axis, expected_gain);
% xlabel('X (cm)');   
% ylabel('Probability/Gain');
% legend('x pdf', 'gain', 'expected gain');

x_opt = x_axis(expected_gain == max(expected_gain));

% y and z axis are not affected by the penalty zone imposed on x axis
target_opt = [x_opt, exp_info.target(2), exp_info.target(3)];

% hopefully the optimal target does not shift too much so that the covariance matrix is similar to the empirical covariance matrix from the practice session
empirical_cov = cov(practice_data);
out.target = target_opt;
out.cov = empirical_cov;

% if penalty_data is not provided, this function is used for simulating endpoint data with a penalty zone
if ~exist('penalty_data', 'var') || isempty(penalty_data)
    out.sample = mvnrnd(target_opt, empirical_cov, exp_info.n_penalty_trial);
% if penalty_data is provided, this function is used for calculating the probability of observing the endpont data given the target and the model
else
    out.prob = normpdf(penalty_data(:,1), target_opt(1), empirical_cov(1,1));   
end

end


function out = optimal_target_model(params)
% ============================================================
% compute_empirical_cov_from_reaching_data.m
%
% Reads your *_reaching_data.tsv (with 2 header lines),
% computes endpoint-error covariance overall and per 27 conditions.
%
% Output:
%   SigmaOverall : 3x3 covariance of (End - Target) across valid trials
%   SigmaByCond  : 3x3x27 covariance per ConditionID (1..27)
%   NByCond      : 27x1 trial counts used per condition
%
% NOTE: Uses cov(X,1) (MLE, divide by N) which matches mvnrnd usage well.
% ============================================================
clear; clc;

[file, path] = uigetfile("*.tsv", "Select your reaching_data.tsv");
if isequal(file,0), error("No file selected."); end
filePath = fullfile(path, file);

opts = detectImportOptions(filePath, "Delimiter", "\t", "FileType", "text");
opts.DataLines = [3 Inf];
T = readtable(filePath, opts);



% ---- 3) build endpoint + target matrices ----
endpts  = [T.EndX T.EndY T.EndZ];
targets = [T.TargetX T.TargetY T.TargetZ];

% ---- 4) validity filter ----
valid = all(isfinite(endpts),2) & all(isfinite(targets),2);

% remove rows where endpoint was never written (common: all zeros)
valid = valid & ~all(endpts == 0, 2);

% remove "Too Slow" (edit this list if you have other fail labels)
if ismember("Result", string(T.Properties.VariableNames))
    r = lower(strtrim(string(T.Result)));
    bad = ismember(r, ["too slow"]);  % add: "too early","invalid start", etc.
    valid = valid & ~bad;
end

% ---- 5) compute endpoint error ----
err = endpts(valid,:) - targets(valid,:);

% ---- 6) overall covariance (3x3) ----
SigmaOverall = cov(err, 1);
disp("=== SigmaOverall (cov of End-Target) ===");
disp(SigmaOverall);

% ---- 7) covariance per 27 conditions ----
SigmaByCond = nan(3,3,27);
NByCond = zeros(27,1);

if ~ismember("ConditionID", string(T.Properties.VariableNames))
    error("ConditionID column not found in table.");
end

cond = T.ConditionID(valid);

for c = 1:27
    Xi = err(cond == c, :);
    NByCond(c) = size(Xi,1);

    if NByCond(c) >= 2
        SigmaByCond(:,:,c) = cov(Xi, 1);
    else
        SigmaByCond(:,:,c) = nan(3,3); % not enough trials
    end
end

disp("=== NByCond (trials used per condition) ===");
disp(NByCond);

% Example: print a specific condition
exampleCond = 17;
disp("=== SigmaByCond for ConditionID " + exampleCond + " ===");
disp(SigmaByCond(:,:,exampleCond));

% ---- 8) (optional) save outputs to a .mat file ----
save("empirical_cov_results.mat", "SigmaOverall", "SigmaByCond", "NByCond");
disp("Saved: empirical_cov_results.mat");

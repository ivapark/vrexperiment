% ----------------------------------------------------------------------
% compute_empirical_cov_from_reaching_data.m
% Reads each subject's *_reaching_data.tsv (with 2 header lines),
% computes endpoint-error covariance overall and per 27 conditions.
% ----------------------------------------------------------------------
% Notes:
% Penalty indexs:
%   0 (no penalty)
%   1 (Penalty on the left of target)
%   2 (Penalty on the right of target)
%
% Uses cov(X,1) (MLE, divide by N) which matches mvnrnd usage well
% ----------------------------------------------------------------------
% Input(s) :
% Unity data
% ----------------------------------------------------------------------
% Output(s):
%   SigmaOverall : 3x3 covariance of (End - Target) across valid trials
%   SigmaByCond  : 3x3x27 covariance per ConditionID (1..27)
%   NByCond      : 25x1 trial counts used per condition
% ----------------------------------------------------------------------
% Function created by Luhe Li (luhe.li@nyu.edu)
% Last edited by : Rachel Chen
% Last update : 2026-02-26
% Project : VR
% Version : 2.0

%clear; close all; clc;

% Subjects to process
%subjectID = {'RC'};

%% ================= LOAD DATA =================
% [file, path] = uigetfile("*.tsv", "Select your reaching_data.tsv");
% if isequal(file,0), error("No file selected."); end
% filePath = fullfile(path, file);

filePattern = fullfile(pwd, '**', [subID '*_reaching_data.tsv']);
filesFound = dir(filePattern);
filePath = fullfile(filesFound(1).folder, filesFound(1).name);

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
    bad = ismember(r, ["too slow", "invalid start", "too early"]);  % 2026-02-26 Rachel added: "too early","invalid start", etc.
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

for c = 0:26
    Xi = err(cond == c, :);
    NByCond(c+1) = size(Xi,1);

    if NByCond(c+1) >= 2
        SigmaByCond(:,:,c+1) = cov(Xi, 1);
    else
        SigmaByCond(:,:,c+1) = nan(3,3);
    end
end

disp("=== NByCond (trials used per condition) ===");
disp(NByCond);

% Example: print a specific condition
exampleCond = 17;
disp("=== SigmaByCond for ConditionID " + exampleCond + " ===");
disp(SigmaByCond(:,:,exampleCond));

% ---- 8) (optional) save outputs to a .mat file ----
baseDir = 'processedData';
subDir = 'empCov';

targetPath = fullfile(pwd, baseDir, subDir);

if ~exist(targetPath, 'dir')
    mkdir(targetPath);
    fprintf('Created directory: %s\n', targetPath);
end

saveFileName = sprintf('%s_empirical_cov_results.mat', subID);
fullSavePath = fullfile(targetPath, saveFileName);

save(fullSavePath, "SigmaOverall", "SigmaByCond", "NByCond");
fprintf('Saved: %s\n', subID);

% save("empirical_cov_results.mat", "SigmaOverall", "SigmaByCond", "NByCond");
% disp("Saved: empirical_cov_results.mat");


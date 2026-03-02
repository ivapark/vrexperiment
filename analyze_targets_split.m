% ----------------------------------------------------------------------
% analyze_targets_split.m
% Raw data processing, resullts contain:
%   1. no-penalty condition;
%   2. penalty condition (split by + & -);
% ----------------------------------------------------------------------
% Notes:
% Penalty indexs:
%   0 (no penalty)
%   1 (Penalty on the left of target)
%   2 (Penalty on the right of target)
% ----------------------------------------------------------------------
% Input(s) :
% Configurations & 'destinationFile' from mainAna.m
% ----------------------------------------------------------------------
% Output(s):
% *_processed_data_disPenDirec.mat
%   (To future Rachel: for file name I was trying to say:
%       distinguish penalty direction)
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Developed based on Luhe Li's code (analyze_targets.m, no-penalty only)
% Last edited by : Rachel Chen
% Last update : 2026-02-27
% Project : VR
% Version : 2.0

%% ================= SWITCHES =================
% Quick check for covariance ellipsoid (adapted from Luhe's code)?
covEllipsoid = 0; % 1 to plot, 0 to skip

%% ================= LOAD DATA =================
filename = destinationFile;

% Step 1: Read the entire file as text
fid = fopen(filename);
fgetl(fid);  % skip metadata line 1
fgetl(fid);  % skip metadata line 2

rawLines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);

rawLines = rawLines{1};
if isempty(rawLines)
    error('File appears empty after skipping metadata lines.');
end

% Step 2: Extract header and data lines
headerLine = strtrim(rawLines{1});
dataLines = rawLines(2:end);

% Split header by *any* whitespace (tabs or spaces)
headers = regexp(headerLine, '\s+', 'split');
headers = matlab.lang.makeValidName(strtrim(headers));

% tep 3: Split each data line into cells ---
splitData = cellfun(@(l) regexp(strtrim(l), '\s+', 'split'), dataLines, 'UniformOutput', false);

nCols = numel(headers);

% Step 4: Normalize row lengths (pad or truncate)
% Step 4.5: Merge split 'Result' tokens like "Invalid Start" and "Too Early"
for i = 1:numel(splitData)
    row = splitData{i};
    if numel(row) > nCols
        % Detect "Invalid Start" or "Too Early" pattern
        for j = 1:(numel(row)-1)
            if strcmp(row{j}, 'Invalid') && strcmp(row{j+1}, 'Start')
                row{j} = 'Invalid Start';
                row(j+1) = [];
                break;
            elseif strcmp(row{j}, 'Too') && strcmp(row{j+1}, 'Slow')
                row{j} = 'Too Slow';
                row(j+1) = [];
                break;
            elseif strcmp(row{j}, 'Hit') && strcmp(row{j+1}, 'Target')
                row{j} = 'Hit Target';
                row(j+1) = [];
                break;
            elseif strcmp(row{j}, 'Hit') && strcmp(row{j+1}, 'Penalty')
                row{j} = 'Hit Penalty';
                row(j+1) = [];
                break;
            elseif strcmp(row{j}, 'Hit') && strcmp(row{j+1}, 'Both')
                row{j} = 'Hit Both';
                row(j+1) = [];
                break;
            elseif strcmp(row{j}, 'Too') && strcmp(row{j+1}, 'Early')
                row{j} = 'Too Early';
                row(j+1) = [];
                break;
            end
        end
    end
    % After merging, ensure correct length again
    if numel(row) < nCols
        row(end+1:nCols) = {''};
    elseif numel(row) > nCols
        row = row(1:nCols);
    end
    splitData{i} = row;
end

% Step 5: Convert to a data matrix
dataMatrix = vertcat(splitData{:});

% Step 6: Convert numeric-looking strings to doubles
for j = 1:nCols
    col = dataMatrix(:,j);
    nums = str2double(col);
    if sum(~isnan(nums)) > 0.9 * numel(nums)   % mostly numeric
        dataMatrix(:,j) = num2cell(nums);
    end
end

% Step 7: Create table
DATA = cell2table(dataMatrix, 'VariableNames', headers);

exclude_mask = strcmp(DATA.Result, 'Invalid Start') | strcmp(DATA.Result, 'Too Slow') | strcmp(DATA.Result, 'Too Early');
DATA(exclude_mask, :) = [];

% Display result
% Find rows with missing values
missingMask = any(ismissing(DATA), 2);
disp('Trials with missing data:');
disp(find(missingMask));
disp('? File loaded successfully with parsed columns.');
disp(['Rows: ', num2str(height(DATA)), ', Columns: ', num2str(width(DATA))]);
disp(DATA(1:min(5,height(DATA)), 1:min(6,width(DATA))));

%% ================= DATA EXTRACTION =================
target_id = unique(DATA.TargetIndex);
n_target = length(target_id);

% Should already loaded 'penalty_axis_tested (1/2/3)' cause
% it determines how PenaltyIndex maps to directions.

% 1 = X axis: PenaltyIndex 1 = Left(-X),    PenaltyIndex 2 = Right(+X)
% 2 = Y axis: PenaltyIndex 1 = Up(+Y),      PenaltyIndex 2 = Down(-Y)
% 3 = Z axis: PenaltyIndex 1 = Forward(+Z),  PenaltyIndex 2 = Back(-Z)

switch penalty_axis_tested
    case 1
        neg_label = 'Left (-X)';   neg_pidx = 1;
        pos_label = 'Right (+X)';  pos_pidx = 2;
    case 2
        neg_label = 'Down (-Y)';   neg_pidx = 2;
        pos_label = 'Up (+Y)';     pos_pidx = 1;
    case 3
        neg_label = 'Back (-Z)';   neg_pidx = 2;
        pos_label = 'Forward (+Z)'; pos_pidx = 1;
end

fprintf('Penalty axis: %d, Negative side: %s (PIdx=%d), Positive side: %s (PIdx=%d)\n', ...
    penalty_axis_tested, neg_label, neg_pidx, pos_label, pos_pidx);

% --- generate empty storage ---
[MU_NP, COV_NP, ENDPOINT_NP] = deal(cell(1, n_target)); % No Penalty
[MU_P,  COV_P,  ENDPOINT_P]  = deal(cell(1, n_target)); % Penalty (combined 1 & 2)
[MU_P_NEG,  COV_P_NEG,  ENDPOINT_P_NEG]  = deal(cell(1, n_target)); % Penalty negative side
[MU_P_POS,  COV_P_POS,  ENDPOINT_P_POS]  = deal(cell(1, n_target)); % Penalty positive side
TARGET = cell(1, n_target);

for ii = 1:n_target
    t_idx = target_id(ii);

    % --- No Penalty (Condition 0) ---
    trials_np = DATA(DATA.TargetIndex == t_idx & DATA.PenaltyIndex == 0, :);
    if ~isempty(trials_np)
        ENDPOINT_NP{ii} = [trials_np.EndX, trials_np.EndY, trials_np.EndZ] * 1e3;
        MU_NP{ii} = mean(ENDPOINT_NP{ii}, 1);
        COV_NP{ii} = cov(ENDPOINT_NP{ii});
        TARGET{ii} = [trials_np.TargetX(1), trials_np.TargetY(1), trials_np.TargetZ(1)] * 1e3;
    end

    % --- Penalty (Condition 1 & 2, combined) ---
    trials_p = DATA(DATA.TargetIndex == t_idx & DATA.PenaltyIndex ~= 0, :);
    if ~isempty(trials_p)
        ENDPOINT_P{ii} = [trials_p.EndX, trials_p.EndY, trials_p.EndZ] * 1e3;
        MU_P{ii} = mean(ENDPOINT_P{ii}, 1);
        COV_P{ii} = cov(ENDPOINT_P{ii});
    end

    % --- Penalty negative side (e.g., Left) ---
    trials_p_neg = DATA(DATA.TargetIndex == t_idx & DATA.PenaltyIndex == neg_pidx, :);
    if ~isempty(trials_p_neg)
        ENDPOINT_P_NEG{ii} = [trials_p_neg.EndX, trials_p_neg.EndY, trials_p_neg.EndZ] * 1e3;
        MU_P_NEG{ii} = mean(ENDPOINT_P_NEG{ii}, 1);
        COV_P_NEG{ii} = cov(ENDPOINT_P_NEG{ii});
    end

    % --- Penalty positive side (e.g., Right) ---
    trials_p_pos = DATA(DATA.TargetIndex == t_idx & DATA.PenaltyIndex == pos_pidx, :);
    if ~isempty(trials_p_pos)
        ENDPOINT_P_POS{ii} = [trials_p_pos.EndX, trials_p_pos.EndY, trials_p_pos.EndZ] * 1e3;
        MU_P_POS{ii} = mean(ENDPOINT_P_POS{ii}, 1);
        COV_P_POS{ii} = cov(ENDPOINT_P_POS{ii});
    end

end %target_id

%% ================= SAVING DATA =================

matFileName = [subID '_processed_data_disPenDirec.mat']; % output .mat name

save(fullfile(output_process_Dir, matFileName), ...
    'ENDPOINT_NP', 'MU_NP', 'COV_NP', ...
    'ENDPOINT_P', 'MU_P', 'COV_P', ...
    'ENDPOINT_P_NEG', 'MU_P_NEG', 'COV_P_NEG', ...
    'ENDPOINT_P_POS', 'MU_P_POS', 'COV_P_POS', ...
    'TARGET', 'penalty_axis_tested', ...
    'neg_label', 'pos_label', 'neg_pidx', 'pos_pidx');

fprintf('Saved processed data for %s to %s\n', subID, matFileName);

%% ================= Ellipsoid plotting =================
if covEllipsoid == 1

    figure('Position',[0,0,2000,2000]);
    hold on;
    axis equal;
    view(3);
    rotate3d on;
    grid on;
    xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
    % xlim([-0.2,0.2]); ylim([0.8 1.2]); zlim([2.4,2.6]);

    for ii = 1:length(target_id)

        % Plot the target
        scatter3(TARGET{ii}(:,1), TARGET{ii}(:,2), TARGET{ii}(:,3), 60, 'r', 'filled', 'DisplayName', 'Target');

        % Plot the endpoints
        scatter3(ENDPOINT{ii}(:,1), ENDPOINT{ii}(:,2), ENDPOINT{ii}(:,3), 30,'k', 'filled','MarkerFaceAlpha',0.5,'DisplayName', 'Endpoints');

        % Plot the covariance ellipsoid
        mu = MU{ii}';
        C = COV{ii};

        % Make a sphere
        n = 30;
        [XS,YS,ZS] = sphere(n);
        SPHERE = [XS(:), YS(:), ZS(:)]';

        [V, S, ~] = svd(C);
        SD = sqrt(S);
        ELLIPSOID = V * SD * SPHERE + mu;
        XE = reshape(ELLIPSOID(1,:), size(XS));
        YE = reshape(ELLIPSOID(2,:), size(YS));
        ZE = reshape(ELLIPSOID(3,:), size(ZS));

        surf(XE,YE,ZE,'FaceColor','b','FaceAlpha',0.3,'EdgeColor','none');

    end
    legend({'Target', 'Endpoints'}, 'Location', 'northeastoutside');

    % fig_dir = fullfile(pwd,['fig', mfilename]);
    % if ~exist(fig_dir); mkdir(fig_dir); end
    % save(fullfile(fig_dir, 'processed_data.mat'),'MU','COV','ENDPOINT','TARGET');

end %covEllipsoid
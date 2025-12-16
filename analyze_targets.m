% ===============================
% analyze_targets.m
% ===============================

% filename = 'IP_2025-09-19_12-47-24_reaching_data.tsv';
% filename = 'IP_2025-10-17_06-43-03_reaching_data.tsv';
filename = 'IP_2025-12-12_17-01-38_reaching_data.tsv';

% --- Step 1: Read the entire file as text ---
fid = fopen(filename);
fgetl(fid);  % skip metadata line 1
fgetl(fid);  % skip metadata line 2
rawLines = textscan(fid, '%s', 'Delimiter', '\n'); 
fclose(fid);

rawLines = rawLines{1};
if isempty(rawLines)
    error('File appears empty after skipping metadata lines.');
end

% --- Step 2: Extract header and data lines ---
headerLine = strtrim(rawLines{1});
dataLines = rawLines(2:end);

% Split header by *any* whitespace (tabs or spaces)
headers = regexp(headerLine, '\s+', 'split');
headers = matlab.lang.makeValidName(strtrim(headers));
% --- Step 3: Split each data line into cells ---
splitData = cellfun(@(l) regexp(strtrim(l), '\s+', 'split'), dataLines, 'UniformOutput', false);

nCols = numel(headers);

% --- Step 4: Normalize row lengths (pad or truncate) ---
% --- Step 4.5: Merge split 'Result' tokens like "Invalid Start" and "Too Early" ---
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


% --- Step 5: Convert to a data matrix ---
dataMatrix = vertcat(splitData{:});

% --- Step 6: Convert numeric-looking strings to doubles ---
for j = 1:nCols
    col = dataMatrix(:,j);
    nums = str2double(col);
    if sum(~isnan(nums)) > 0.9 * numel(nums)   % mostly numeric
        dataMatrix(:,j) = num2cell(nums);
    end
end

% --- Step 7: Create table ---
DATA = cell2table(dataMatrix, 'VariableNames', headers);

exclude_mask = strcmp(DATA.Result, 'Invalid Start') | strcmp(DATA.Result, 'Too Slow') | strcmp(DATA.Result, 'Too Early');
DATA(exclude_mask, :) = [];

% --- Display result ---
% Find rows with missing values
missingMask = any(ismissing(DATA), 2);
disp('Trials with missing data:');
disp(find(missingMask));
disp('? File loaded successfully with parsed columns.');
disp(['Rows: ', num2str(height(DATA)), ', Columns: ', num2str(width(DATA))]);
disp(DATA(1:min(5,height(DATA)), 1:min(6,width(DATA))));

%% Covariance matrix of the no-penalty condition

% Extract trials with no penalty condition
no_penalty_trials = DATA(DATA.PenaltyIndex == 0, :);
target_id = unique(DATA.TargetIndex);

for ii = 1:length(target_id)

    % Trials of this target, no penalty condition
    this_target_trials = no_penalty_trials(no_penalty_trials.TargetIndex == target_id(ii), :);
    target_coor = [this_target_trials.TargetX, this_target_trials.TargetY, this_target_trials.TargetZ]*1e3;
    target_coor = unique(target_coor, 'rows');
    TARGET{ii} = target_coor;

    % Data of these 
    endpoint = [this_target_trials.EndX, this_target_trials.EndY, this_target_trials.EndZ]*1e3;
    ENDPOINT{ii} = endpoint;
    MU{ii} = mean(endpoint,1);
    COV{ii} = cov(endpoint);

end

%%

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

fig_dir = fullfile(pwd,['fig', mfilename]);
if ~exist(fig_dir); mkdir(fig_dir); end
save(fullfile(fig_dir, 'processed_data.mat'),'MU','COV','ENDPOINT','TARGET');
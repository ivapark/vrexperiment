% ===============================
% analyze_targets.m
% ===============================

% filename = 'IP_2025-09-19_12-47-24_reaching_data.tsv';
% filename = 'IP_2025-10-17_06-43-03_reaching_data.tsv';
filename = 'IP_2025-10-17_13-22-38_reaching_data.tsv';

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

nCols = numel(headers)
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
reaching = cell2table(dataMatrix, 'VariableNames', headers);

% --- Display result ---
% Find rows with missing values
missingMask = any(ismissing(reaching), 2);
disp('Trials with missing data:');
disp(find(missingMask));
disp('? File loaded successfully with parsed columns.');
disp(['Rows: ', num2str(height(reaching)), ', Columns: ', num2str(width(reaching))]);
disp(reaching(1:min(5,height(reaching)), 1:min(6,width(reaching))));

% organize data
numInvalidStart = sum(strcmp(reaching.Result, 'Invalid Start'));

%% separate trials with no penalty
noPenaltyTrials = reaching(reaching.PenaltyX == 0 & reaching.PenaltyY == 0 & reaching.PenaltyZ == 0, :);
penaltyTrials = reaching(reaching.PenaltyX ~= 0 | reaching.PenaltyY ~= 0 | reaching.PenaltyZ ~= 0, :);
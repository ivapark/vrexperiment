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

%% Plot all targets together

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

%% One target per subplot

figure('Position',[0,0,2000,2000], 'Color','w');

nTargets = numel(target_id);
nCols = ceil(sqrt(nTargets));
nRows = ceil(nTargets / nCols);
target_order = [7,8,9,4,5,6,1,2,3];

n = 30;
[XS,YS,ZS] = sphere(n);
SPHERE = [XS(:), YS(:), ZS(:)]'; 

for ii = 1:nTargets
    ax = subplot(nRows, nCols, target_order(ii));
    hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal');
    rotate3d(ax, 'on');
    view(45, 75); % azimuth=45°, elevation=80°
    camup([0 1 0]); 
    xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)'); zlabel(ax,'Z (mm)');

    % Data
    T = TARGET{ii};
    E = ENDPOINT{ii};

    mu = MU{ii};
    if isrow(mu), mu = mu'; end
    C  = COV{ii};

    % Dots
    hT = scatter3(ax, T(:,1), T(:,2), T(:,3), 60, 'r', 'filled');
    hE = scatter3(ax, E(:,1), E(:,2), E(:,3), 30, 'k', 'filled', ...
        'MarkerFaceAlpha', 0.5);

    % Covariance ellipsoid
    [V,S,~] = svd(C);
    SD = sqrt(S);
    ELLIPSOID = V * SD * SPHERE + mu;

    XE = reshape(ELLIPSOID(1,:), size(XS));
    YE = reshape(ELLIPSOID(2,:), size(YS));
    ZE = reshape(ELLIPSOID(3,:), size(ZS));

    hEl = surf(ax, XE, YE, ZE, 'FaceColor','b', 'FaceAlpha',0.25, 'EdgeColor','none');

    % Projection walls
    allPts = [T; E; [XE(:), YE(:), ZE(:)]];
    xmin = min(allPts(:,1)); xmax = max(allPts(:,1));
    ymin = min(allPts(:,2)); ymax = max(allPts(:,2));
    zmin = min(allPts(:,3)); zmax = max(allPts(:,3));
    dx = max(eps, xmax-xmin); dy = max(eps, ymax-ymin); dz = max(eps, zmax-zmin);

    wallPad = 0.2; % how far the walls sit outside the data
    yLeft  = ymin - wallPad*dy; % XZ wall to the "left" (constant Y)
    xBack  = xmin - wallPad*dx; % YZ wall to the "back"  (constant X)

    % Draw translucent wall planes
    % XZ wall (left): y = yLeft
    surf(ax, [xmin xmax; xmin xmax], [yLeft yLeft; yLeft yLeft], [zmin zmin; zmax zmax], ...
        'FaceAlpha',0.06,'EdgeColor','none');

    % YZ wall (back): x = xBack
    surf(ax, [xBack xBack; xBack xBack], [ymin ymax; ymin ymax], [zmin zmin; zmax zmax], ...
        'FaceAlpha',0.06,'EdgeColor','none');

    % Project TARGET/ENDPOINT dots onto the walls
    % onto XZ (left wall): keep x,z; set y=yLeft
    scatter3(ax, T(:,1), yLeft*ones(size(T,1),1), T(:,3), 30, 'r', 'filled', 'MarkerFaceAlpha',0.25);
    scatter3(ax, E(:,1), yLeft*ones(size(E,1),1), E(:,3), 20, 'k', 'filled', 'MarkerFaceAlpha',0.15);

    % onto YZ (back wall): keep y,z; set x=xBack
    scatter3(ax, xBack*ones(size(T,1),1), T(:,2), T(:,3), 30, 'r', 'filled', 'MarkerFaceAlpha',0.25);
    scatter3(ax, xBack*ones(size(E,1),1), E(:,2), E(:,3), 20, 'k', 'filled', 'MarkerFaceAlpha',0.15);

    % Project ellipsoid mesh as a light point cloud onto the walls
    % onto XZ (left)
    scatter3(ax, XE(:), yLeft*ones(numel(XE),1), ZE(:), 6, 'b', 'filled', 'MarkerFaceAlpha',0.05);
    % onto YZ (back)
    scatter3(ax, xBack*ones(numel(XE),1), YE(:), ZE(:), 6, 'b', 'filled', 'MarkerFaceAlpha',0.05);

    % Expand limits so walls are visible
    xlim(ax, [xBack - 0.02*dx, xmax + 0.02*dx]);
    ylim(ax, [yLeft - 0.02*dy, ymax + 0.02*dy]);
    zlim(ax, [zFloor - 0.02*dz, zmax + 0.02*dz]);

    title(ax, sprintf('Target %s', string(target_order(ii))), 'Interpreter','none');

    if target_order(ii)==1
        legend(ax, [hT, hE, hEl], {'Target','Endpoints','Ellipsoid'}, 'Location','best');
    end
end

% --- Save as before ---
fig_dir = fullfile(pwd, ['fig', mfilename]);
if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

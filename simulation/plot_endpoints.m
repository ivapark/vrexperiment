clear; clc;

% ---- pick your reaching_data.tsv ----
[file, path] = uigetfile("*.tsv", "Select your reaching_data.tsv");
if isequal(file,0), error("No file selected."); end
filePath = fullfile(path, file);

% ---- read table (skip 2 header lines) ----
opts = detectImportOptions(filePath, "Delimiter", "\t", "FileType", "text");
opts.DataLines = [3 Inf];
T = readtable(filePath, opts);

% ---- validity filter ----
endpts  = [T.EndX T.EndY T.EndZ];
targets = [T.TargetX T.TargetY T.TargetZ];

valid = all(isfinite(endpts),2) & all(isfinite(targets),2);
valid = valid & ~all(endpts==0,2); % drop unwritten endpoints

if ismember("Result", string(T.Properties.VariableNames))
    valid = valid & ~strcmpi(string(T.Result), "Too Slow"); % edit if you want
end

T = T(valid,:);

% ---- penalty mapping (given by you) ----
% PenaltyIndex: 0 = none, 1 = left, 2 = right
if ~ismember("PenaltyIndex", string(T.Properties.VariableNames))
    error("PenaltyIndex column not found.");
end

% ---- 9 targets table for plotting ----
targetTbl = unique(T(:, {'TargetIndex','TargetX','TargetY','TargetZ'}), 'rows');
targetTbl = sortrows(targetTbl, 'TargetIndex');

% ---- 3 separate 3D plots ----
plotOne3D(T(T.PenaltyIndex==1,:), targetTbl, "Left penalty (PenaltyIndex=1)");
plotOne3D(T(T.PenaltyIndex==2,:), targetTbl, "Right penalty (PenaltyIndex=2)");
plotOne3D(T(T.PenaltyIndex==0,:), targetTbl, "No penalty (PenaltyIndex=0)");

% ==========================
% Local function at END
% ==========================
function plotOne3D(Tsub, targetTbl, titleStr)
    figure; hold on; grid on;

    if ~isempty(Tsub)
        scatter3(Tsub.EndX, Tsub.EndY, Tsub.EndZ, 18, 'filled'); % endpoints
    else
        % keep legend stable even if empty
        scatter3(nan,nan,nan,18,'filled');
    end

    scatter3(targetTbl.TargetX, targetTbl.TargetY, targetTbl.TargetZ, ...
        120, 'x', 'LineWidth', 2); % targets

    for j = 1:height(targetTbl)
        text(targetTbl.TargetX(j), targetTbl.TargetY(j), targetTbl.TargetZ(j), ...
            "  T" + targetTbl.TargetIndex(j), 'FontSize', 10, 'FontWeight', 'bold');
    end

    xlabel('X'); ylabel('Y'); zlabel('Z');
    title(titleStr);
    axis equal;
    view(45, 25);
    legend({'Endpoints','Targets'}, 'Location','best');

    % fit axes
    allX = [Tsub.EndX; targetTbl.TargetX];
    allY = [Tsub.EndY; targetTbl.TargetY];
    allZ = [Tsub.EndZ; targetTbl.TargetZ];

    if ~isempty(allX)
        pad = 0.05;
        rx = range(allX); if rx==0, rx=1; end
        ry = range(allY); if ry==0, ry=1; end
        rz = range(allZ); if rz==0, rz=1; end
        xlim([min(allX)-pad*rx, max(allX)+pad*rx]);
        ylim([min(allY)-pad*ry, max(allY)+pad*ry]);
        zlim([min(allZ)-pad*rz, max(allZ)+pad*rz]);
    end

    hold off;
end

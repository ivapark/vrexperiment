% ===============================
% analyze_targets.m
% ===============================

% filename = 'IP_2025-09-19_12-47-24_reaching_data.tsv';
filename = 'IP_2025-10-17_13-22-38_reaching_data.tsv';
T = readtable(filename, 'FileType', 'text', 'Delimiter', '\t', 'ReadVariableNames', false);

% --- Convert endpoint columns (Var21–Var23) to numeric ---
x = str2double(erase(T.Var21, "'"));
y = str2double(erase(T.Var22, "'"));
z = str2double(erase(T.Var23, "'"));

% --- Remove rows with 0 or NaN (optional cleanup) ---
valid = ~(isnan(x) | isnan(y) | isnan(z) | (x==0 & y==0 & z==0));
x = x(valid);
y = y(valid);
z = z(valid);

% --- Plot ---
figure;
scatter3(x, y, z, 60, 'filled');
xlabel('X Position');
ylabel('Y Position');
zlabel('Z Position');
title('3D Endpoints of Reaching Trials');
grid on;
axis equal;

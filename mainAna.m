% ----------------------------------------------------------------------
% mainAna.m
% Main function to run analysis and plotting
% ----------------------------------------------------------------------
% Notes:
% -
% ----------------------------------------------------------------------
% Input(s):
% -
% ----------------------------------------------------------------------
% Output(s):
% -
% ----------------------------------------------------------------------
% Function created by Rachel Chen (qc898@nyu.edu)
% Last update : 2026-03-02
% Last edited by : Rachel Chen
% Project : VR
% Version : 2.0
% ----------------------------------------------------------------------

clear; close all; clc;

%% ================= SWITCHES =================

mfAna = 1;
Model_1d = 1;
Model_3d = 1;

%% ================= LOAD CONFIGURATIONS =================

loadConfig = fullfile(pwd, 'fxnConfig.m');

if exist(loadConfig, 'file')
    run(loadConfig);
else
    error('No Configurations file found !!!');
end

% Helper function path
rootPath = fileparts(mfilename('fullpath'));
utilPath = fullfile(rootPath, 'util');
addpath(genpath(utilPath));
addpath(genpath(fullfile(rootPath, '1D')));
addpath(genpath(fullfile(rootPath, '3D')));

%% ================= SETTINGS =================

% ---------- Subject (s) to run ----------
subjectID = {'RC'};

% ---------- Folder names ----------

% folder name for rawData
rawFolderName = 'rawData';
% Create path
if ~exist(rawFolderName, 'dir')
    mkdir(rawFolderName);
end

% folder name for processed data
output_process_Dir = fullfile(pwd, 'processedData','splitPenalty');
% Create path
if ~exist(output_process_Dir, 'dir')
    mkdir(output_process_Dir);
end

% ---------- Penalty Setting ----------
% Which penalty axis was tested?
% X:1; Y: 2; Z: 3;
penalty_axis_tested = 1;




%   1 = X axis: PenaltyIndex 1 = Left(-X),    PenaltyIndex 2 = Right(+X)
%   2 = Y axis: PenaltyIndex 1 = Up(+Y),      PenaltyIndex 2 = Down(-Y)
%   3 = Z axis: PenaltyIndex 1 = Forward(+Z),  PenaltyIndex 2 = Back(-Z)

%% ================= ANALYSIS BEGIN =================

for sub = 1:length(subjectID)

    subID = subjectID{sub};

    fprintf('Now processing %s \n', subID);
    %% ================= FILE MANAGEMENT =================
    % Rachel being compulsive...

    % Find Unity daata file, pattern should be: 'subjectID_xxxxxx_reaching_data'.tsv
    filePattern = fullfile(pwd, '**',[subID '*_reaching_data.tsv']);
    filesFound = dir(filePattern);

    % Do we have the file?
    if ~isempty(filesFound)
        for j = 1:length(filesFound)
            sourceFile = fullfile(filesFound(j).folder, filesFound(j).name);

            % Renaming(e.g. RC_rawData.tsv)
            newFileName = [subID '_rawData.tsv'];
            destinationFile = fullfile(pwd, rawFolderName, newFileName);

            copyfile(sourceFile, destinationFile);
        end
    else
        fprintf('No Unity data for subject %s \n', subID);
    end

    if mfAna == 1 % start model free analysis
        %% ================= MODEL-FREE ANALYSIS =================

        % --- Function 1 ---
        % preprocessing
        analyze_targets_split

        % --- Function 2 ---
        % empirical endpoints 3D visualization
        EP_3D

        % --- Function 3 ---
        % projection to xyz axes
        xyz_projection_butterfly

        % --- Function 4 ---
        % model free stats
        fprintf('\n Now start descriptive stats for %s \n', subID);
        mf_shiftAna_split

    end %mfAna

    %% ================= MODEL-BASED ANALYSIS =================

    % --- Function 1 ---
    % creating covariance matrix
    cov_from_reachingdata

    if Model_1d == 1
        %% ================= 1D IDEAL OBSERVER MODEL =================

        % --- Function 1 ---
        % run 1D model simulation
        ideal_observer_1D

        % --- Function 2 ---
        % projection to 1D optimal shifty
        project_to_optimal_shift_1D

    end % Model_1d

    if Model_3d == 1
        %% ================= 3D IDEAL OBSERVER MODEL =================

        % --- Function 1 ---
        % run 3D model simulation
        ideal_observer_3D

        % --- Function 2 ---
        % projection to 3D optimal shifty
        project_to_optimal_shift_3D

    end % Model_3d

    fprintf('\n Subject %s is all set!!!!!!!!!!! \n', subID);

end % sub loop
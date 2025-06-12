%% latest version unfold script

init_unfold

% receiving files from output of sequence_labeling code
% datasetFolder = 'Z:\Experiments\RedLightGreenLight\EEG_Files_SM\New_trigs\processed\output_test';
datasetFolder = '\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_test';
datasetFiles = dir(fullfile(datasetFolder, '*.set')); % Get all .set files
numDatasets = length(datasetFiles);

% Preallocate storage for uf_results parameters
allResults = struct();
allResults.datasetNames = strings(1, numDatasets);

% create output folder for csv files
% csv_dc_folder = 'Z:\Experiments\Deconvolution\output_deconvolution\csv_dc';
% csv_no_dc_folder = 'Z:\Experiments\Deconvolution\output_deconvolution\csv_no_dc';

% csv_dc_folder = './output_dc_csv';
% csv_no_dc_folder = './output_no_dc_csv';

% outputFolder = 'C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_deconvolution';
% outputFolder = 'Z:\Experiments\Deconvolution\output_deconvolution';

if ~exist(csv_dc_folder, 'dir')
    mkdir(csv_dc_folder);
end

if ~exist(csv_no_dc_folder, 'dir')
    mkdir(csv_no_dc_folder);
end

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end


for i = 1: numDatasets
    EEG = pop_loadset('filename', datasetFiles(i).name, 'filepath', datasetFolder);
    EEG = eeg_checkset(EEG);
    
    % initializing array to subset EEG data we are observing 
    cfgDesign = [];
    
    % defining event types for low and high constraint - separating the two
    cfgDesign.eventtypes = {'high', 'low'};
    
    % explicit formula: y = 1 + fix_type + constraint + fix_type:constraint
    cfgDesign.formula = {'y ~ 1 + cat(fix_type) * cat(constraint)', 'y ~ 1 + cat(fix_type)*cat(constraint)'};
    
    % Make sure both types are explicitly included
    cfgDesign.categorical = {'fix_type', {'single_fix', 'first_of_multiple', 'second_of_multiple', 'others'},...
                            'constraint',{'HC', 'LC'}}; 
   
    % initializes sparse matrix with the events and variables stated
    EEG = uf_designmat(EEG,cfgDesign);
    
    % defines the timeperiod we are observing over (-500ms to 800ms)
    cfgTimeexpand = [];
    cfgTimeexpand.timelimits = [-.5,0.8];
    EEG = uf_timeexpandDesignmat(EEG,cfgTimeexpand);
    
    % identify "bad" intervals artifacts in the continuous EEG...
    winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',200,'channels',16); 
    % important to exclude synchronized eye-tracker channels for this step (if they exist)
    
    % ...and remove them from time-expanded design matrix
    EEG = uf_continuousArtifactExclude(EEG,struct('winrej',winrej));
    
    % Fitting deconvolution model
    
    EEG = uf_glmfit(EEG,'channel',16); 
    EEG = uf_epoch(EEG,struct('winrej',winrej,'timelimits',cfgTimeexpand.timelimits));
    
    % new epoched dataset, condensing dataset, fitting non-deconvolved model
    
    EEG = uf_glmfit_nodc(EEG); 
    ufresult= uf_condense(EEG, 'channel', 16);

    % Debug: Print specific fields we're interested in
    disp('Fields in ufresult:')
    disp(fieldnames(ufresult))
    
    % Store relevant fields from ufresult
    allResults.datasetNames(i) = datasetFiles(i).name;
    allResults.beta{i} = ufresult.beta;       % Model dc_coefficients
    allResults.beta_nodc{i} = ufresult.beta_nodc;       % Model non_dc_coefficients
    allResults.times{i} = ufresult.times;     % Timepoints
    allResults.chanlocs{i} = ufresult.chanlocs; % Channel locations
    allResults.param{i} = ufresult.param;     % Model parameters
    allResults.unfold{i} = ufresult.unfold;   % Extra Unfold data (if needed)
    
    % Export to CSV with dataset identifier
    [~, baseFileName, ~] = fileparts(datasetFiles(i).name);  % Extract filename without extension
    filename_dc = sprintf('%s_unfold_dc.csv', baseFileName);
    fullpath_dc = fullfile(csv_dc_folder, filename_dc);  % Create full path including output folder
    uftable = uf_unfold2csv(ufresult,  'deconv', 1, 'filename', fullpath_dc);

    filename_no_dc = sprintf('%s_unfold_no_dc.csv', baseFileName);
    fullpath_no_dc = fullfile(csv_no_dc_folder, filename_dc);  % Create full path including output folder
    uftable2 = uf_unfold2csv(ufresult, 'deconv', 0, 'filename',  fullpath_no_dc);

    
    % Debug: Print the structure of ufresult to see what's available
    disp('Structure of ufresult:')
    disp(ufresult)
end

% Save all betas in one .mat file
save(fullfile(outputFolder, 'all_betas.mat'), 'allResults');
disp(['All dataset parameters in ', datasetFolder, ' saved!']);

% plot the deconvoluted and non-dc betas of last loaded dataset
% uf_plotParam(ufresult, 'plotParam', 'fix_type:constraint');
g = uf_plotParam(ufresult,'deconv',1, 'add_intercept', 1, 'baseline', [ufresult.times(1) 0]);
f = uf_plotParam(ufresult,'deconv',0,'add_intercept', 1, 'baseline', [ufresult.times(1) 0],'gramm',g); % color this one


%% function recoverERPs - contrast
% recover the modeled ERPs of last loaded dataset
beta = squeeze(ufresult.beta);   % [time × 8]

% -------- HIGH constraint sentence -----------------
erp_high_first   = beta * [1 0 0 0  0 0 0 0]';   % β0h + β1h
erp_high_second  = beta * [1 0 1 0  0 0 0 0]';
erp_high_single  = beta * [1 0 0 1  0 0 0 0]';
erp_high_others  = beta * [1 0 0 1  0 0 0 0]';

% -------- LOW constraint sentence ------------------
erp_low_first    = beta * [0 0 0 0  1 1 0 0]';
erp_low_second   = beta * [0 0 0 0  1 0 1 0]';
erp_low_single   = beta * [0 0 0 0  1 0 0 1]';
erp_low_others   = beta * [0 0 0 0  1 0 0 0]';

%% manually baseline correcting the graphs

% time vector (seconds)
t  = ufresult.times;               

% logical index for the baseline window, here –200…0 ms
bl = t >= -0.5000 & t <= 0;

%% subtract average for each and every condition separately

% debug baseline window values
% disp([t(find(bl,1,'first')) , t(find(bl,1,'last'))])

baselineERP = @(erp) erp - mean(erp(bl,:), 1);

% Low-constraint conditions
erp_low_first   = baselineERP(erp_low_first);
erp_low_second  = baselineERP(erp_low_second);
erp_low_single  = baselineERP(erp_low_single);
erp_low_others  = baselineERP(erp_low_others);

% High-constraint conditions
erp_high_first  = baselineERP(erp_high_first);
erp_high_second = baselineERP(erp_high_second);
erp_high_single = baselineERP(erp_high_single);
erp_high_others = baselineERP(erp_high_others);

%% plotting baseline corrected modelled ERPs

% function for plot styling 
function stylePlot()
    % add legend
    legend({'first-of-multiple', 'second-of-multiple', 'single-fix', 'others'}, ...
        'Location', 'best');
    
    % horizontal dotted line at 0 µV
    yline(0, 'k:');
    
    % adding a grid, dotted, 40% opaque
    grid on
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
    
    % flip the y-axis so that n400 looks deflected up
    set(gca, 'YDir', 'reverse');

    xlabel('Time (ms)'); ylabel('µV');
end


% figure
% plot(erp_high_first,'r'), hold on
% plot(erp_high_second,'g')
% plot(erp_high_single, 'b')
% plot(erp_high_others, 'k')
% title('High Constraint Fixation-aligned FRPs, baseline -100…0 ms');
% stylePlot()
% 
% figure
% plot(erp_low_first,'r'), hold on
% plot(erp_low_second,'g')
% plot(erp_low_single, 'b')
% plot(erp_low_others, 'k')
% title('Low Constraint Fixation-aligned FRPs (baseline -100…0 ms');
% stylePlot()





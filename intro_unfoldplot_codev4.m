init_unfold

% receiving files from output of sequence_labeling code
datasetFolder = '\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_sequence_labeling';
datasetFiles = dir(fullfile(datasetFolder, '*.set')); % Get all .set files
numDatasets = length(datasetFiles);

% Preallocate storage for uf_results parameters
allResults = struct();
allResults.datasetNames = strings(1, numDatasets);

% create output folder for csv files
csv_dc_folder = './output_dc_csv';
csv_no_dc_folder = './output_no_dc_csv';

if ~exist(csv_dc_folder, 'dir')
    mkdir(csv_dc_folder);
end

if ~exist(csv_no_dc_folder, 'dir')
    mkdir(csv_no_dc_folder);
end

for i = 1: numDatasets
    EEG = pop_loadset('filename', datasetFiles(i).name, 'filepath', datasetFolder);
    EEG = eeg_checkset(EEG);
    
    % initializing array to subset EEG data we are observing 
    cfgDesign = [];
    
    % defining event types for low and high constraint 
    cfgDesign.eventtypes = {'fixation'};
    
    % explicit formula: y = 1 + type + fix_type + type:fix_type {interaction effect}
    cfgDesign.formula = {'y ~ 1 + cat(constraint)*cat(fix_type) + cat(constraint)*cat(fix_index)'}; 
    
    %cfgDesign.codingschema = 'effects';   %will look into after paper
    
    % Make sure both types are explicitly included
    cfgDesign.categorical = {'constraint', {'HC', 'LC'},...
                            'fix_type', {'refix', 'single'},...
                            'fix_index', {'first_fix', 'next_fix'}}; 
    
    
    % initializes sparse matrix with the events and variables stated
    EEG = uf_designmat(EEG,cfgDesign);
    
    % defines the timeperiod we are observing over (-300ms to 800ms)
    cfgTimeexpand = [];
    cfgTimeexpand.timelimits = [-.3,0.8];
    EEG = uf_timeexpandDesignmat(EEG,cfgTimeexpand);
    
    % identify "bad" intervals artifacts in the continuous EEG...
    winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',200,'channels',16); % important to exclude synchronized eye-tracker channels for this step (if they exist)
    
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

outputFolder = 'C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_deconvolution';

% Save all betas in one .mat file
save(fullfile(outputFolder, 'all_betas.mat'), 'allResults');
disp(['All dataset parameters in ', datasetFolder, ' saved!']);

% plot the deconvoluted and non-dc betas of last loaded dataset
g = uf_plotParam(ufresult,'deconv',1, 'add_intercept', 1, 'baseline', [ufresult.times(1) 0]);
g = uf_plotParam(ufresult,'deconv',0,'add_intercept', 1, 'baseline', [ufresult.times(1) 0],'gramm',g);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ERPplots

% in erp_plots_disp (in development)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
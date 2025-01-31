init_unfold

% receiving files from output of sequence_labeling code
datasetFolder = 'C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_sequence_labeling';
datasetFiles = dir(fullfile(datasetFolder, '*.set')); % Get all .set files
numDatasets = length(datasetFiles);

% Preallocate storage for uf_results parameters
allResults = struct();
allResults.datasetNames = strings(1, numDatasets);

for i = 1: numDatasets
    EEG = pop_loadset('filename', datasetFiles(i).name, 'filepath', datasetFolder);
    EEG = eeg_checkset(EEG);
    
    % initializing array to subset EEG data we are observing 
    cfgDesign = [];
    
    % defining event types for low and high constraint 
    cfgDesign.eventtypes = {'1312','1311'};
    
    % explicit formula: y = 1 + type + fix_type + type:fix_type {interaction effect}
    cfgDesign.formula = {'y ~ 1 + cat(type)*cat(fix_type)'}; 
    
    % Make sure both types are explicitly included
    cfgDesign.categorical = {'type', {'1311', '1312'},...
                            'fix_type', {'single', 'first_refix', 'second_refix'}}; 
    
    % initializes sparse matrix with the events and variables stated
    EEG = uf_designmat(EEG,cfgDesign);
    
    % defines the timeperiod we are observing over (-300ms to 800ms)
    cfgTimeexpand = [];
    cfgTimeexpand.timelimits = [-.3,0.8];
    EEG = uf_timeexpandDesignmat(EEG,cfgTimeexpand);
    
    % identify "bad" intervals artifacts in the continuous EEG...
    winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',100,'channels',16); % important to exclude synchronized eye-tracker channels for this step (if they exist)
    
    % ...and remove them from time-expanded design matrix
    EEG = uf_continuousArtifactExclude(EEG,struct('winrej',winrej));
    
    % replacing nans in the design matrix with zeroes
    % EEG.unfold.Xdc(isnan(EEG.unfold.Xdc)) = 0;
    
    % Fitting deconvolution model
    EEG = uf_glmfit(EEG,'channel',16); 
    
    % new epoched dataset, fitting non-deconvolved model
    EEG_epoch = uf_epoch(EEG,struct('winrej',winrej,'timelimits',cfgTimeexpand.timelimits));
    
    % condensing dataset
    ufresult= uf_condense(EEG_epoch);

    % Store relevant fields from ufresult
    allResults.datasetNames(i) = datasetFiles(i).name;
    allResults.beta{i} = ufresult.beta;       % Model coefficients
    allResults.times{i} = ufresult.times;     % Timepoints
    allResults.chanlocs{i} = ufresult.chanlocs; % Channel locations
    allResults.param{i} = ufresult.param;     % Model parameters
    allResults.unfold{i} = ufresult.unfold;   % Extra Unfold data (if needed)

    % debugging
    % display(ufresult)
    
    % Debug: Print the structure of ufresult to see what's available
    disp('Structure of ufresult:')
    disp(ufresult)
end

outputFolder = 'C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output_deconvolution';

% Save all betas in one .mat file
save(fullfile(outputFolder, 'all_betas.mat'), 'ufresult');
disp(['All dataset parameters in ', datasetFolder, ' saved!']);

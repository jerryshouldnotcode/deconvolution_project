init_unfold

% change this later for group data
EEG = pop_loadset('C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output\modified_RLGL011_ICA.set');
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

% debugging
display(ufresult)

% Debug: Print the structure of ufresult to see what's available
disp('Structure of ufresult:')
disp(ufresult)

% Plot with more explicit parameters
g1 = uf_plotParam(ufresult, 'channel', 16, ...
    'deconv', 1, ...
    'baseline', [ufresult.times(1) 0], ...
    'plotSeparate', 'event');
g1.set_color_options('map', [0 0 1]); % RGB for blue
g1.update();

% Optional: Add second plot for non-deconvoluted betas
% g2 = uf_plotParam(ufresult, 'channel', 16, ...
%     'deconv', 0, ...
%     'baseline', [ufresult.times(1) 0], ...
%     'plotParam', {'type_1311', 'type_1312'}, ... % Explicitly specify both types
%     'gramm', g1);
% g2.set_color_options('map', [1 0 0]); % RGB for red
% g2.update();
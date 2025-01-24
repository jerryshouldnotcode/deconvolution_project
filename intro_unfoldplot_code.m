init_unfold

% change this later for group data
EEG = pop_loadset('C:\Users\HP\Documents\MATLAB\projects\fixation-label for deconvolution\output\modified_RLGL011_ICA.set');
EEG = eeg_checkset(EEG);

% initializing array to subset EEG data we are observing 
cfgDesign = [];

% defining event types for low and high constraint 
cfgDesign.eventtypes = {'1312','1311'};

% intercept only  
cfgDesign.formula = {'y ~ 1 + cat(label)+ cat(type)'}; % at every timepoint? 

% debugging
disp(unique({EEG.event.type}))
% disp(unique([EEG.event.fixationNumber]));
% disp(class([EEG.event.fixationNumber]))


% setting events to be observed for the categorical variables
cfgDesign.categorical = {'type', {'1312', '1311'};
                        'label', {'FirstFixation', 'Refixation'}}; 

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

% plots all parameters; general plot
uf_plotParam(ufresult,'channel',16);

% plot conditions on top of each other, reverse y-axis direction

% First plot: Deconvoluted betas (Blue)
g1 = uf_plotParam(ufresult, 'channel', 16, 'deconv', 1, 'baseline' , [ufresult.times(1) 0]);
g1.set_color_options('map', [0 0 1]); % RGB for blue
g1.update(); 

% Second plot: Non-deconvoluted betas (Red)
% g2 = uf_plotParam(ufresult, 'channel', 16, 'deconv', 0, 'baseline', [ufresult.times(1) 0], 'gramm', g1);
% g2.set_color_options('map', [1 0 0]); % RGB for red
% g2.update();
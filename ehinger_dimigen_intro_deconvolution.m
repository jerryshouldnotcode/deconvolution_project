init_unfold
EEG = pop_loadset('C:\Users\HP\Desktop\Ehinger_Dimigen_unfoldtoolbox_opendata\face_saccades_opendata_fig10.set');
cfgDesign = [];
cfgDesign.eventtypes = {'saccade','stimonset'};
% We use intercept-only formulas because we are only interested in the overlap for now
cfgDesign.formula = {'y ~ 1','y~1'};
EEG = uf_designmat(EEG,cfgDesign);

cfgTimeexpand = [];
cfgTimeexpand.timelimits = [-.3,0.8];
EEG = uf_timeexpandDesignmat(EEG,cfgTimeexpand);

% A simple threshold function taken from ERPLAB
winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',250);

% We remove very noisy data segments (>250mV) from the designmatrix
EEG = uf_continuousArtifactExclude(EEG,struct('winrej',winrej));

EEG= uf_glmfit(EEG,'channel',16);

% We need to provide the same winrej as before, so that approximately the same data is used for the model. 
% Only approximately because in epoched data we need to remove a whole trial, whereas deconvolution allows
% partial trial-data to be used.
% Be aware that if you decide to overwrite the EEG structure you need to reload your data to rerun your analysis on continuous data
EEG = uf_epoch(EEG,struct('winrej',winrej,'timelimits',cfgTimeexpand.timelimits));

EEG = uf_glmfit_nodc(EEG); 

ufresult= uf_condense(EEG);
display(ufresult)

uf_plotParam(ufresult,'channel',16);

%first plot the deconvoluted betas
g = uf_plotParam(ufresult,'channel',16,'deconv',1,'baseline',[ufresult.times(1) 0]);

% now plot the non-deconvoluted betas
g = uf_plotParam(ufresult,'channel',16,'deconv',0,'baseline',[ufresult.times(1) 0],'gramm',g);
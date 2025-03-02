init_unfold

projectFolder = '\fixation-label for deconvolution\output_deconvolution';

% Load the data
filename = 'all_betas.mat';  % Replace with your actual .mat filename
tmp = load(fullfile(projectFolder, filename));
ufresult = tmp.ufresult;

%% plot deconv vs nodeconv
% This does not work with splines 
cfg = [];
cfg.channel = 16; % channel location
cfg.add_intercept = 0;
cfg.baseline = [min(ufresult.times) 0];

%% figure plotting
% try
%     % First attempt with standard plotting
%     uf_plot2nd(ufresult,cfg);
% catch
%     % Alternative plotting approach
%     g = uf_plotParam(ufresult, 'channel', cfg.channel, ...
%         'deconv', 1, ...
%         'baseline', cfg.baseline, ...
%         'plotSeparate', 'event', ...
%         'plotCI', 'sem');  % Add confidence intervals using standard error of the mean
%     g.set_color_options('map', [0 0 1]); % RGB for blue
%     g.draw();
% end

% This function calculates a channel matrix that can be used for default cluster-permutation tests
% using the ept-TFCE toolbox
ept_tfce_nb = ept_ChN2(ufresult.chanlocs,1); % the 1 to plot
disp(ept_tfce_nb)

% Average amount of neighbours:
mean(sum(ept_tfce_nb'>0))

cfg = [];

% excluding eye-movement channels from the Eye-EEG toolbox
cfg.chan = 1:30; 

cfg.pred = 4; % predictability at a target-word

% subselect channels & predictor  
data = squeeze(ufresult.beta(cfg.chan,:,cfg.pred,:));

% baseline correction
data = bsxfun(@minus,data,mean(data(:,ufresult.times<0,:),2));

% do the statistics
% this is a customized version of the original ept_tfce_diff function
res = ept_lme_TFCE('data',permute(data,[3 1 2]),'perm_data',500,'channel_neighbours',ept_tfce_nb(cfg.chan,:));

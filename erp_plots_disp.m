
% % load a sample dataset in erp_plots_disp

%% actual plotting
cfg = {
    'channel', 16, ...
    'sort_time', [],...
    'alignto', 'fixation',...
    'split_by', 'fix_type',...
    'overlap', 0
};

% unsorted, overlap-estimate
% uf_erpimage(EEG, 'channel', 16); 

% sorting EEG data by condition across raw and modelled
% 'sort_by' has to be an event column in EEG.event
uf_erpimage(EEG,'type','raw','sort_by', 'duration', cfg{:});
uf_erpimage(EEG, 'type', 'modelled', 'sort_by', 'duration', cfg{:});

% checking overlap
% uf_erpimage(EEG,'overlap',0,cfg{:});
uf_erpimage(EEG,'type', 'residual','overlap',1,cfg{:});

% sorting EEG data by event across raw and modelled - second_refix
% uf_erpimage(EEG,'type','raw','sort_time', [0 1.5],'sort_alignto','next_fix', cfg{:}) %currently stuck

% comparing modeled data with and without overlap
% uf_erpimage(EEG, 'type', 'modelled', 'overlap', 1, 'keep',{'(Intercept)'}','sort_by', 'type', 'addResiduals', 1, cfg{:});
% uf_erpimage(EEG, 'type', 'modelled', 'overlap',1 ,'remove',{'(Intercept)'}, 'sort_by', 'type', 'addResiduals', 1, cfg{:});
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
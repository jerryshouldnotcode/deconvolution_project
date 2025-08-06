%% latest version unfold script

init_unfold

% receiving files from output of sequence_labeling code
% datasetFolder = 'Z:\Experiments\RedLightGreenLight\EEG_Files_SM\New_trigs\processed\output_test';
datasetFolder = fullfile(pwd, 'eyesort_filter_output');
datasetFiles = dir(fullfile(datasetFolder, '*.set')); % Get all .set files
numDatasets = length(datasetFiles);

% Preallocate storage for uf_results parameters
allResults = struct();
allResults.datasetNames = strings(1, numDatasets);

% Initialize folder for storing each participant's data (dc, non-dc)
output_folder = fullfile(pwd, 'output_deconvolution'); 
csv_dc_folder = './output_deconvolution/output_dc_csv';
csv_no_dc_folder = './output_deconvolution/output_no_dc_csv';

% create folders if they don't exist
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

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
    
    % defining event types...

    % 110101, 110201, 110303, 110401, - HC_Other
    % 120101, 120201, 120303, 120401  - LC_Other
    % 110305         - HC_Target_Word_Single
    % 120305         - LC_Target_Word_Single
    % 110302         - HC_Target Word, First Pass, First of Multiple
    % 120302         - LC_Target Word, First Pass, First of Multiple
    % 110304         - HC_Target Word, First Pass, Second of Multiple
    % 120304         - LC_Target Word, First Pass, Second of Multiple


    % cfgDesign.eventtypes = {['110101', '110201', '110302', '110401', '110305'],...
    %     ['120101', '120201', '120303', '120401', '120305', '120302', '110304']};

    % uh, not dealing with that - turning these numbers to high and low
    % constraint (vectorized version)

    % Extract the first two characters of each event type
    firstTwoChars = cellfun(@(x) x(1:2), {EEG.event.type}, 'UniformOutput', false);

    highIndex = strcmp(firstTwoChars, '11'); % '11' corresponds to type '1' and '1'
    lowIndex = strcmp(firstTwoChars, '12');  % '12' corresponds to type '1' and '2'
    
    % Assign new types based on the conditions
    [EEG.event(highIndex).type] = deal('high');
    [EEG.event(lowIndex).type] = deal('low');


    % ask Brandon about this - bdf_filter_description a double?
    if isnumeric(EEG.event(1).bdf_filter_description)
        for k = 1:numel(EEG.event)
            EEG.event(k).bdf_filter_description = strtrim(num2str(EEG.event(k).bdf_filter_description));
        end
    else
        % trimming whitespace, arghhhh
        for k = 1:numel(EEG.event)
            EEG.event(k).bdf_filter_description = strtrim(EEG.event(k).bdf_filter_description);
        end
    end

    %{
    bdf_condition_description - contains constraint
    bdf_filter_description - contains fixation type
    
    explicit formula: y = 1 + fix_type + constraint 
    %}

    cfgDesign.eventtypes = {'high', 'low'};

    cfgDesign.formula = {'y ~ 1 + cat(bdf_filter_description) + cat(bdf_condition_description)',...
       'y ~ 1 + cat(bdf_filter_description) + cat(bdf_condition_description)'};

    % Make sure both types are explicitly included
    % cfgDesign.categorical = {'fix_type', {'single_fix', 'first_of_multiple', 'second_of_multiple', 'others'},...
    %                         'constraint',{'HC', 'LC'}}; 

    disp('bdf_filter_description:');
    disp(unique({EEG.event.bdf_filter_description}));
    disp('bdf_condition_description:');
    disp(unique({EEG.event.bdf_condition_description}));

    cfgDesign.categorical = {'bdf_filter_description', {'Single', 'First of Multiple',...
    'Second of Multiple',  'Other'},...
         'bdf_condition_description', {'HC', 'LC'}};
   
    % initializes sparse matrix with the events and variables stated
    EEG = uf_designmat(EEG,cfgDesign);
    
    % defines the timeperiod we are observing over (-500ms to 800ms)
    cfgTimeexpand = [];
    cfgTimeexpand.timelimits = [-.5,0.8];
    EEG = uf_timeexpandDesignmat(EEG,cfgTimeexpand);
    
    % identify "bad" intervals artifacts in the continuous EEG...
    winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',200,'channels',[15 16 17 20 21 24 25 26]); 
    % important to exclude synchronized eye-tracker channels for this step (if they exist)
    
    % ...and remove them from time-expanded design matrix
    EEG = uf_continuousArtifactExclude(EEG,struct('winrej',winrej));
    
    % Fitting deconvolution model along ROI - Cz, C3, C4, Cp1, Cp2, Pz, P3, P4

    EEG = uf_glmfit(EEG,'channel',[15 16 17 20 21 24 25 26]); 
    EEG = uf_epoch(EEG,struct('winrej',winrej,'timelimits',cfgTimeexpand.timelimits));
    
    % new epoched dataset, condensing dataset, fitting non-deconvolved
    % model (same ROI)
   
    EEG = uf_glmfit_nodc(EEG); 
    ufresult= uf_condense(EEG, 'channel', [15 16 17 20 21 24 25 26]);

    % Export to CSV with dataset identifier
    [~, baseFileName, ~] = fileparts(datasetFiles(i).name);  % Extract filename without extension
    filename_dc = sprintf('%s_unfold_dc.csv', baseFileName);
    fullpath_dc = fullfile(csv_dc_folder, filename_dc);  % Create full path including output folder
    uftable = uf_unfold2csv(ufresult,  'deconv', 1, 'filename', fullpath_dc);

    filename_no_dc = sprintf('%s_unfold_no_dc.csv', baseFileName);
    fullpath_no_dc = fullfile(csv_no_dc_folder, filename_no_dc);  % Create full path including output folder
    uftable2 = uf_unfold2csv(ufresult, 'deconv', 0, 'filename',  fullpath_no_dc);

end


%% doesn't need to be here, reference for ideas in group averaging 

% If uf_plotParam expects a 2D beta (time x channels), reshape:
% chan_avg_struct.beta = reshape(chan_avg_struct.beta, [], 1);

% % Now plot
% g = uf_plotParam(chan_avg_struct, 'deconv', 1, 'add_intercept', 0, 'baseline', [chan_avg_struct.times(1) 0]);
% f = uf_plotParam(chan_avg_struct, 'deconv',0,'add_intercept', 0, 'baseline', [ufresult.times(1) 0],'gramm',g,'style',[0 1 0]); % color this one green 
% 
% 
% %% function recoverERPs - contrast
% % recover the modeled ERPs of last loaded dataset
% beta = squeeze(ufresult.beta);   % [time × 8]
% 
% % -------- HIGH constraint sentence -----------------
% erp_high_first   = beta * [1 0 0 0 1 0  0 0 0 0 0 0]';   % β0h + β1h
% erp_high_second  = beta * [1 0 1 0 1 0  0 0 0 0 0 0]';
% erp_high_single  = beta * [1 0 0 1 1 0  0 0 0 0 0 0]';
% erp_high_others  = beta * [1 0 0 1 1 0  0 0 0 0 0 0]';
% 
% % -------- LOW constraint sentence ------------------
% erp_low_first    = beta * [0 0 0 0 0 0  1 1 0 0 0 1]';
% erp_low_second   = beta * [0 0 0 0 0 0  1 0 1 0 0 1]';
% erp_low_single   = beta * [0 0 0 0 0 0  1 0 0 1 0 1]';
% erp_low_others   = beta * [0 0 0 0 0 0  1 0 0 0 0 1]';
% 
% %% manually baseline correcting the graphs
% 
% % time vector (seconds)
% t  = ufresult.times;               
% 
% % logical index for the baseline window, here –200…0 ms
% bl = t >= -0.5000 & t <= 0;
% 
% %% subtract average for each and every condition separately
% 
% % debug baseline window values
% % disp([t(find(bl,1,'first')) , t(find(bl,1,'last'))])
% 
% baselineERP = @(erp) erp - mean(erp(bl,:), 1);
% 
% % Low-constraint conditions
% erp_low_first   = baselineERP(erp_low_first);
% erp_low_second  = baselineERP(erp_low_second);
% erp_low_single  = baselineERP(erp_low_single);
% erp_low_others  = baselineERP(erp_low_others);
% 
% % High-constraint conditions
% erp_high_first  = baselineERP(erp_high_first);
% erp_high_second = baselineERP(erp_high_second);
% erp_high_single = baselineERP(erp_high_single);
% erp_high_others = baselineERP(erp_high_others);
% 
% %% plotting baseline corrected modelled ERPs
% 
% % function for plot styling 
% function stylePlot()
%     % add legend
%     legend({'first-of-multiple', 'second-of-multiple', 'single-fix', 'others'}, ...
%         'Location', 'best');
% 
%     % horizontal dotted line at 0 µV
%     yline(0, 'k:');
% 
%     % adding a grid, dotted, 40% opaque
%     grid on
%     set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
% 
%     % flip the y-axis so that n400 looks deflected up
%     set(gca, 'YDir', 'reverse');
% 
%     xlabel('Time (ms)'); ylabel('µV');
% end
% 
% 
% % figure
% % plot(erp_high_first,'r'), hold on
% % plot(erp_high_second,'g')
% % plot(erp_high_single, 'b')
% % plot(erp_high_others, 'k')
% % title('High Constraint Fixation-aligned FRPs, baseline -100…0 ms');
% % stylePlot()
% % 
% % figure
% % plot(erp_low_first,'r'), hold on
% % plot(erp_low_second,'g')
% % plot(erp_low_single, 'b')
% % plot(erp_low_others, 'k')
% % title('Low Constraint Fixation-aligned FRPs (baseline -100…0 ms');
% % stylePlot()
 

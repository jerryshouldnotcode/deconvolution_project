% Initialize EEGLAB
eeglab;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Consider leaving this as './datasets' so you dont have to set the directory %
% each time this is run on a new machine. The user simply has to have a       %
% folder named 'datasets' in the directory                                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specify the path to the datasets folder
datasets_folder = './datasets';

% Get a list of all .set files in the datasets folder
dataset_files = dir(fullfile(datasets_folder, '*.set'));
disp(dataset_files)

% Generate output folder if it doesn't exist
output_folder = './output_test';
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Process each .set file
for file_idx = 1:length(dataset_files)
    
    % Load the current .set file
    EEG = pop_loadset('filename', dataset_files(file_idx).name, 'filepath', datasets_folder);
    
    % Displays the name of the file being processed
    disp(['Processing file: ', dataset_files(file_idx).name]);

    % Initialize the 'constraint', 'fix_type' fields if they don't exist
    % Create and initialize to empty
    if ~isfield(EEG.event, 'constraint')
        [EEG.event.constraint] = deal('[]');  
    end
    
    % Add new fixationType field
    if ~isfield(EEG.event, 'fix_type')
        [EEG.event.fix_type] = deal('[]');
    end
    
     % Add new fixation index field
    if ~isfield(EEG.event, 'fix_index')
        [EEG.event.fix_index] = deal('[]');
    end

    % Populate the 'constraint' field based on event type
    for i = 1:length(EEG.event)
        
        % Finds '1311' code in the 'type' column
        if strcmp(EEG.event(i).type, '1311')
            
            % Fills the 'constraint' column with 'HC' to signify High Constraint
            EEG.event(i).constraint = 'HC';
         
        % Finds '1312' code in the 'type' column
        elseif strcmp(EEG.event(i).type, '1312')
            
            % Fills the 'constraint' column with 'LC' to signify Low Constraint
            EEG.event(i).constraint = 'LC';
        
        end
    end

    % Iterate through events to identify S254 (start of trial) and S255 (end of trial)
    for i = 1:length(EEG.event)
        if strcmp(EEG.event(i).type, 'S254')
            % Reset counter for new trial
            fix_counter = 0;
            
            % Start searching from the next event
            j = i + 1;
            
            % Process until end of trial (S255)
            while j <= length(EEG.event) && ~strcmp(EEG.event(j).type, 'S255')
                % Check for first fixation (1311 or 1312)
                if strcmp(EEG.event(j).type, '1311') || strcmp(EEG.event(j).type, '1312')
                    fix_counter = fix_counter + 1;
                    
                    % Check for refixation sequence (current + R_saccade + same fixation)
                    if j <= length(EEG.event) - 2 && ...
                       strcmp(EEG.event(j+1).type, 'R_saccade') && ...
                       strcmp(EEG.event(j+2).type, EEG.event(j).type)
                        
                        % Mark as refixation sequence
                        EEG.event(j).fix_type = 'refix';
                        EEG.event(j+2).fix_type = 'refix';
                        EEG.event(j).fix_index = 'first_fix';
                        EEG.event(j+2).fix_index = 'next_fix';

                        % Skip to next trial
                        break;
                    else
                        % No refixation sequence found, mark as single
                        EEG.event(j).fix_type = 'single_fix';
                        EEG.event(j+2).fix_type = 'single_fix';
                        EEG.event(j).fix_index = 'first_fix';
                        EEG.event(j+2).fix_index = 'next_fix';
                        break;
                    end
                end
                j = j + 1;
            end
        end
    end
    
    % Clear fix_index field, replace fix_type
    for i = 1:length(EEG.event)

        % rows that have constraint and no fixation type - others 
        if (strcmp(EEG.event(i).fix_type, '[]'))  ...
                && (strcmp(EEG.event(i).constraint, 'LC')...
                ||  strcmp(EEG.event(i).constraint, 'HC'))
            EEG.event(i).fix_type = 'others';
        end

        if strcmp(EEG.event(i).fix_type, 'refix') && strcmp(EEG.event(i).fix_index, 'first_fix')
            EEG.event(i).fix_type = 'first of multiple';

        elseif strcmp(EEG.event(i).fix_type, 'refix') && strcmp(EEG.event(i).fix_index, 'next_fix')
            EEG.event(i).fix_type = 'second of multiple';

        elseif strcmp(EEG.event(i).fix_type, 'single_fix') && strcmp(EEG.event(i).fix_index, 'first_fix' )
            EEG.event(i).fix_type = 'single_first_fix';
        
        elseif strcmp(EEG.event(i).fix_type, 'single_fix') && strcmp(EEG.event(i).fix_index, 'next_fix' )
            EEG.event(i).fix_type = 'single_next_fix';
        
        end

        EEG.event(i).fix_index = [];
    end

    % Create a logical array that is true for events that meet the condition.
    removeIdx = arrayfun(@(ev) strcmp(ev.constraint, '[]') && strcmp(ev.fix_type, '[]'), EEG.event);

    % Remove those events.
    EEG.event(removeIdx) = [];
    
    % Save the modified EEG structure to the output folder
    modified_filename = ['modified_', dataset_files(file_idx).name];
    pop_saveset(EEG, 'filename', modified_filename, 'filepath', output_folder);

    % Export event data to CSV
    eventData = struct2table(EEG.event);
    output_filename_csv = fullfile(output_folder, ['modified_', dataset_files(file_idx).name(1:end-4), '_event_data.csv']);
    writetable(eventData, output_filename_csv);
    disp(['Event data saved to: ', output_filename_csv]);
end

disp('Processing completed!');

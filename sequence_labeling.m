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

% Generate output folder if it doesn't exist
output_folder = './output';
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Process each .set file
for file_idx = 1:length(dataset_files)
    
    % Load the current .set file
    EEG = pop_loadset('filename', dataset_files(file_idx).name, 'filepath', datasets_folder);
    
    % Displays the name of the file being processed
    disp(['Processing file: ', dataset_files(file_idx).name]);

    % Initialize the 'constraint', 'label', and 'fixationNumber' fields if they don't exist
    % Create and initialize to empty
    if ~isfield(EEG.event, 'constraint')
        [EEG.event.constraint] = deal('');  
    end
    
    % Create and initialize to empty
    if ~isfield(EEG.event, 'label')
        [EEG.event.label] = deal(' ');  
    end
    
    % Create and initialize to empty
    if ~isfield(EEG.event, 'fixationNumber')
        [EEG.event.fixationNumber] = deal(NaN);
        
    end

    % Display unique event types for debugging
    unique_event_types = unique({EEG.event.type});
    disp('Unique event types in the dataset:');
    disp(unique_event_types);

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
        % Start of a new trial
        if strcmp(EEG.event(i).type, 'S254')
            % Reset fixation counter and flag for each trial
            fixationCounter = 0; 
            hasEncounteredFixation = false;
    
            % Debugging purposes
            disp(['Processing trial starting at index ', num2str(i)]);
    
            % Start searching from the next event
            j = i + 1;
    
            % Iterate through the trial until the end of the trial is reached ('S255')
            while j <= length(EEG.event) && ~strcmp(EEG.event(j).type, 'S255')
    
                % Check for condition: first '1311' or '1312' within the trial
                if ~hasEncounteredFixation && (strcmp(EEG.event(j).type, '1311') || strcmp(EEG.event(j).type, '1312'))
                    % Mark that the first fixation has been encountered
                    hasEncounteredFixation = true;
    
                    % Increment fixation counter
                    fixationCounter = fixationCounter + 1;
    
                    % Populate the 'fixationNumber' field with the fixation count
                    EEG.event(j).fixationNumber = fixationCounter;
                    
                    % Labels as First Fixation in label column
                    EEG.event(j).label = 'FirstFixation';
    
                    % Debugging purposes
                    disp(['First fixation found: index ', num2str(j), ...
                          ', type: ', EEG.event(j).type, ...
                          ', fixationNumber: ', num2str(fixationCounter)]);
                elseif hasEncounteredFixation && ...
                       (strcmp(EEG.event(j).type, '1311') || strcmp(EEG.event(j).type, '1312'))
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % Check for the specific sequence: '1311' or '1312' → 'R-saccade' → same '1311' or '1312'
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if j <= length(EEG.event) - 2 && ...
                       strcmp(EEG.event(j+1).type, 'R_saccade') && ...
                       strcmp(EEG.event(j+2).type, EEG.event(j).type)
                        % Increment fixation counter for refixation
                        fixationCounter = fixationCounter + 1;
    
                        % Update the 'label' and 'fixationNumber' fields for the refixation
                        EEG.event(j+2).label = 'Refixation';
                        EEG.event(j+2).fixationNumber = fixationCounter;
    
                        % Debugging
                        disp(['Refixation sequence detected: ', EEG.event(j).type, ...
                              ' → R_saccade → ', EEG.event(j+2).type, ...
                              ' at indices ', num2str(j), ', ', num2str(j+1), ', ', num2str(j+2), ...
                              ', fixationNumber: ', num2str(fixationCounter)]);
                    end
                else
                    % Debugging for skipped events
                    disp(['Event skipped: index ', num2str(j), ', type: ', EEG.event(j).type]);
                end
    
                % Move to the next event
                j = j + 1;
            end
        end
    end




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

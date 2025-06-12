%% group_averaging.m

function group_averaging_main()
    % Main workflow for group averaging of EEG data
    fprintf('Starting group averaging workflow...\n');
    
    % Define folder paths
    % csv_dc_folder = './output_dc_csv';
    % csv_no_dc_folder = './output_no_dc_csv';

    csv_dc_folder = 'Z:\Experiments\Deconvolution\output_deconvolution\csv_dc';
    csv_no_dc_folder = 'Z:\Experiments\Deconvolution\output_deconvolution\csv_no_dc';

    
    % Step 1: Load and validate data
    fprintf('\n=== Step 1: Loading and validating data ===\n');
    [dc_data, nondc_data] = load_and_validate_data(csv_dc_folder, csv_no_dc_folder);
    
    % Step 2: Concatenate data across files
    fprintf('\n=== Step 2: Concatenating data across files ===\n');
    [combined_dc, combined_nondc] = concatenate_data(dc_data, nondc_data);
    
    % Step 3: Calculate group averages
    fprintf('\n=== Step 3: Calculating group averages ===\n');
    [final_dc, final_nondc] = calculate_group_averages(combined_dc, combined_nondc);
    
    % Step 4: Save results
    fprintf('\n=== Step 4: Saving results ===\n');
    save_results(final_dc, final_nondc, combined_dc, combined_nondc);
    
    fprintf('\nGroup averaging workflow completed successfully!\n');
end

function [dc_data, nondc_data] = load_and_validate_data(csv_dc_folder, csv_no_dc_folder)
    % Load all CSV files and validate time consistency
    
    % Get file lists
    dc_files = dir(fullfile(csv_dc_folder, '*.csv'));
    nondc_files = dir(fullfile(csv_no_dc_folder, '*.csv'));
    num_files = length(dc_files);
    
    if length(nondc_files) ~= num_files
        error('Mismatch in number of files between DC (%d) and non-DC (%d) folders', ...
            num_files, length(nondc_files));
    end
    
    fprintf('Found %d file pairs to process\n', num_files);
    
    % Initialize storage
    dc_data = cell(1, num_files);
    nondc_data = cell(1, num_files);
    dc_times = cell(1, num_files);
    nondc_times = cell(1, num_files);
    
    % Load all files
    for i = 1:num_files
        % Load DC data
        dc_filepath = fullfile(csv_dc_folder, dc_files(i).name);
        dc_table = readtable(dc_filepath);
        dc_table = add_file_prefix_to_columns(dc_table, i);
        dc_data{i} = dc_table;
        dc_times{i} = dc_table.time;
        
        % Load non-DC data
        nondc_filepath = fullfile(csv_no_dc_folder, nondc_files(i).name);
        nondc_table = readtable(nondc_filepath);
        nondc_table = add_file_prefix_to_columns(nondc_table, i);
        nondc_data{i} = nondc_table;
        nondc_times{i} = nondc_table.time;
        
        fprintf('Loaded file pair %d of %d\n', i, num_files);
    end
    
    % Validate time consistency
    validate_time_consistency(dc_times, nondc_times, dc_files, nondc_files);
end

function data_table = add_file_prefix_to_columns(data_table, file_idx)
    % Add file prefix to data columns (not metadata columns)
    
    metadata_cols = {'event', 'predictor', 'predictorvalue', 'channel', 'time'};
    all_cols = data_table.Properties.VariableNames;
    data_cols = ~ismember(all_cols, metadata_cols);
    
    % Rename data columns with file prefix
    new_cols = all_cols;
    new_cols(data_cols) = cellfun(@(x) sprintf('file%d_%s', file_idx, x), ...
        all_cols(data_cols), 'UniformOutput', false);
    data_table.Properties.VariableNames = new_cols;
end

function validate_time_consistency(dc_times, nondc_times, dc_files, nondc_files)
    % Check that all time columns are consistent
    
    num_files = length(dc_times);
    
    % Check DC consistency
    dc_consistent = true;
    for i = 2:num_files
        if ~isequal(dc_times{1}, dc_times{i})
            dc_consistent = false;
            fprintf('Time mismatch in DC files: %s vs %s\n', ...
                dc_files(1).name, dc_files(i).name);
        end
    end
    
    % Check non-DC consistency
    nondc_consistent = true;
    for i = 2:num_files
        if ~isequal(nondc_times{1}, nondc_times{i})
            nondc_consistent = false;
            fprintf('Time mismatch in non-DC files: %s vs %s\n', ...
                nondc_files(1).name, nondc_files(i).name);
        end
    end
    
    % Check between DC and non-DC
    between_consistent = isequal(dc_times{1}, nondc_times{1});
    
    % Report results
    fprintf('Time consistency check:\n');
    fprintf('  Within DC folder: %s\n', bool_to_string(dc_consistent));
    fprintf('  Within non-DC folder: %s\n', bool_to_string(nondc_consistent));
    fprintf('  Between DC and non-DC: %s\n', bool_to_string(between_consistent));
    
    if ~(dc_consistent && nondc_consistent && between_consistent)
        error('Time column inconsistencies detected! Cannot proceed with averaging.');
    end
    
    fprintf('All time columns are consistent - proceeding with analysis\n');
end

function [combined_dc, combined_nondc] = concatenate_data(dc_data, nondc_data)
    % Concatenate numeric data columns across all files
    
    num_files = length(dc_data);
    
    % Get metadata from first file
    metadata_cols = get_metadata_columns(dc_data{1});
    
    % Process DC data
    fprintf('Processing DC data...\n');
    [dc_numeric_data, dc_colnames] = extract_and_concatenate_numeric_data(dc_data);
    combined_dc = [metadata_cols, array2table(dc_numeric_data, 'VariableNames', dc_colnames)];
    
    % Process non-DC data  
    fprintf('Processing non-DC data...\n');
    [nondc_numeric_data, nondc_colnames] = extract_and_concatenate_numeric_data(nondc_data);
    combined_nondc = [metadata_cols, array2table(nondc_numeric_data, 'VariableNames', nondc_colnames)];
    
    fprintf('Successfully concatenated data:\n');
    fprintf('  DC: %d rows x %d columns (%d numeric data columns)\n', ...
        size(combined_dc, 1), size(combined_dc, 2), size(dc_numeric_data, 2));
    fprintf('  Non-DC: %d rows x %d columns (%d numeric data columns)\n', ...
        size(combined_nondc, 1), size(combined_nondc, 2), size(nondc_numeric_data, 2));
end

function metadata_cols = get_metadata_columns(data_table)
    % Extract metadata columns from a data table
    metadata_col_names = {'event', 'predictor', 'predictorvalue', 'channel', 'time'};
    metadata_cols = data_table(:, metadata_col_names);
end

function [numeric_data, colnames] = extract_and_concatenate_numeric_data(data_cell_array)
    % Extract and concatenate numeric columns from multiple tables
    
    num_files = length(data_cell_array);
    metadata_cols = {'event', 'predictor', 'predictorvalue', 'channel', 'time'};
    
    % Identify numeric columns from first file
    first_table = data_cell_array{1};
    all_cols = first_table.Properties.VariableNames;
    data_cols = ~ismember(all_cols, metadata_cols);
    data_col_names = all_cols(data_cols);
    
    % Check which columns are numeric
    numeric_mask = false(size(data_col_names));
    for j = 1:length(data_col_names)
        col_data = first_table.(data_col_names{j});
        numeric_mask(j) = isnumeric(col_data);
    end
    
    fprintf('  Found %d numeric columns out of %d data columns\n', ...
        sum(numeric_mask), length(numeric_mask));
    
    % Concatenate numeric data across all files
    numeric_data = [];
    colnames = {};
    
    for i = 1:num_files
        current_table = data_cell_array{i};
        current_cols = current_table.Properties.VariableNames;
        current_data_cols = ~ismember(current_cols, metadata_cols);
        current_data_col_names = current_cols(current_data_cols);
        
        % Select only numeric columns
        numeric_col_names = current_data_col_names(numeric_mask);
        numeric_table = current_table(:, numeric_col_names);
        
        % Concatenate
        if i == 1
            numeric_data = table2array(numeric_table);
            colnames = numeric_col_names;
        else
            numeric_data = [numeric_data, table2array(numeric_table)];
            colnames = [colnames, numeric_col_names];
        end
        
        fprintf('  Processed file %d of %d\n', i, num_files);
    end
end

function [final_dc, final_nondc] = calculate_group_averages(combined_dc, combined_nondc)
    % Get metadata columns
    metadata_and_time = combined_dc(:, 1:5);  % event, predictor, predictorvalue, channel, time
    
    % Calculate mean across all data columns for each row
    mean_dc = mean(combined_dc{:, 6:end}, 2);  % average across columns 6 to end
    mean_nondc = mean(combined_nondc{:, 6:end}, 2);
    
    % Create final tables
    final_dc = [metadata_and_time, array2table(mean_dc, 'VariableNames', {'mean_value'})];
    final_nondc = [metadata_and_time, array2table(mean_nondc, 'VariableNames', {'mean_value'})];
end

function save_results(final_dc, final_nondc, combined_dc, combined_nondc)
    % Save all results to CSV files
    
    % Save averaged results
    writetable(final_dc, 'group_averaged_dc.csv');
    writetable(final_nondc, 'group_averaged_nondc.csv');
    
    % Save full combined tables
    writetable(combined_dc, 'combined_all_dc.csv');
    writetable(combined_nondc, 'combined_all_nondc.csv');
    
    fprintf('Saved files:\n');
    fprintf('  group_averaged_dc.csv\n');
    fprintf('  group_averaged_nondc.csv\n');
    fprintf('  combined_all_dc.csv\n');
    fprintf('  combined_all_nondc.csv\n');
end

function str = bool_to_string(bool_val)
    % Convert boolean to string for display
    if bool_val
        str = 'PASS';
    else
        str = 'FAIL';
    end
end

% Run the main function
group_averaging_main();
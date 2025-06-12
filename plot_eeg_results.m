%% plot_eeg_results.m
% Script to visualize group-averaged EEG results

% Load the group-averaged data
fprintf('Loading group-averaged data...\n');
final_dc = readtable('group_averaged_dc.csv');
final_nondc = readtable('group_averaged_nondc.csv');

% Create time series plots
fprintf('Creating time series plots...\n');
% Create separate figures for high and low
figure('Name', 'High Events', 'Position', [100 100 1200 800]);
figure('Name', 'Low Events', 'Position', [100 100 1200 800]);

% Get unique channels
channels = unique(final_dc.channel);
num_channels = length(channels);

% Get unique event and predictor combinations
[unique_events, ~, event_idx] = unique(final_dc.event);
[unique_predictors, ~, predictor_idx] = unique(final_dc.predictor);

% Create all possible combinations
unique_combos = cell(0, 2);
for k = 1:length(unique_events)
    % Get all predictors for this event
    event_data = final_dc(strcmp(final_dc.event, unique_events{k}), :);
    event_predictors = unique(event_data.predictor);
    
    % Create a combination for each predictor of this event
    for p = 1:length(event_predictors)
        unique_combos{end+1,1} = unique_events{k};
        unique_combos{end,2} = event_predictors{p};
    end
end
num_combos = size(unique_combos, 1);

% Debug
fprintf('Number of combinations: %d\n', num_combos);
fprintf('Combinations:\n');
disp(unique_combos);

% Count combinations for each event type
high_combos = sum(cellfun(@(x) strcmp(x, 'high'), unique_combos(:,1)));
low_combos = sum(cellfun(@(x) strcmp(x, 'low'), unique_combos(:,1)));
fprintf('Number of combinations for high constraint: %d\n', high_combos);
fprintf('Number of combinations for low constraint: %d\n', low_combos);

% Setting up baseline function
t = final_dc.time; % where t is a time vector
baseline_interval = t >= -0.200 & t <= 0; % time period I want to average over
baselineERP = @(erp) erp - mean(erp(baseline_interval,:), 1); % function subtracting erp condition from it's average


% Create subplots for each channel and combination
for i = 1:num_channels
    high_counter = 1;  % Counter for high combinations
    low_counter = 1;   % Counter for low combinations
    
    for j = 1:num_combos
        % Select figure based on event type
        if strcmp(unique_combos{j,1}, 'high')
            figure(1);
            subplot(num_channels, high_combos, (i-1)*high_combos + high_counter);
            high_counter = high_counter + 1;
        else
            figure(2);
            subplot(num_channels, low_combos, (i-1)*low_combos + low_counter);
            low_counter = low_counter + 1;
        end
        
        % Get data for current channel and combination
        channel_mask = cellfun(@(x) strcmp(x, channels{i}), final_dc.channel);
        event_mask = cellfun(@(x) strcmp(x, unique_combos{j,1}), final_dc.event);
        predictor_mask = cellfun(@(x) strcmp(x, unique_combos{j,2}), final_dc.predictor);
        
        % % Debug prints
        % fprintf('Channel mask size: %d\n', length(channel_mask));
        % fprintf('Combo mask size: %d\n', length(combo_mask));
        % fprintf('Number of true values in channel_mask: %d\n', sum(channel_mask));
        % fprintf('Number of true values in combo_mask: %d\n', sum(combo_mask));
        
        % Get beta values for this combination
        channel_data = final_dc(channel_mask & event_mask & predictor_mask, :);
        nondc_channel_data = final_nondc(channel_mask & event_mask & predictor_mask, :);
        
        % Baseline correction for each condition in channel dc and non-dc
        % Recover ERPs from betas using design matrix coefficients
        if strcmp(unique_combos{j,1}, 'high')
            % High constraint conditions
            if strcmp(unique_combos{j,2}, 'first')
                erp_dc = channel_data.mean_value * [1 1 0 0 0 0 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [1 1 0 0 0 0 0 0]';
            elseif strcmp(unique_combos{j,2}, 'second')
                erp_dc = channel_data.mean_value * [1 0 1 0 0 0 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [1 0 1 0 0 0 0 0]';
            elseif strcmp(unique_combos{j,2}, 'single')
                erp_dc = channel_data.mean_value * [1 0 0 1 0 0 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [1 0 0 1 0 0 0 0]';
            else % others
                erp_dc = channel_data.mean_value * [1 0 0 0 0 0 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [1 0 0 0 0 0 0 0]';
            end
        else
            % Low constraint conditions
            if strcmp(unique_combos{j,2}, 'first')
                erp_dc = channel_data.mean_value * [0 0 0 0 1 1 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [0 0 0 0 1 1 0 0]';
            elseif strcmp(unique_combos{j,2}, 'second')
                erp_dc = channel_data.mean_value * [0 0 0 0 1 0 1 0]';
                erp_nondc = nondc_channel_data.mean_value * [0 0 0 0 1 0 1 0]';
            elseif strcmp(unique_combos{j,2}, 'single')
                erp_dc = channel_data.mean_value * [0 0 0 0 1 0 0 1]';
                erp_nondc = nondc_channel_data.mean_value * [0 0 0 0 1 0 0 1]';
            else % others
                erp_dc = channel_data.mean_value * [0 0 0 0 1 0 0 0]';
                erp_nondc = nondc_channel_data.mean_value * [0 0 0 0 1 0 0 0]';
            end
        end
        
        % Plot DC and non-DC data
        plot(channel_data.time, channel_data.mean_value, 'b-', 'LineWidth', 1.5);
        hold on;
        plot(nondc_channel_data.time, nondc_channel_data.mean_value, 'r--', 'LineWidth', 1.5);
        
        % Add labels and title
        title(sprintf('Channel: %s\nEvent: %s, Predictor: %s', ...
            channels{i}, unique_combos{j,1}, unique_combos{j,2}));
        xlabel('Time (s)');
        ylabel('Amplitude');
        legend('DC', 'Non-DC');
        grid on;
        
        % Add vertical line at t=0.798
        xline(0.798, 'k--', 'LineWidth', 1);
    end
end

% % Create topographical maps
% fprintf('Creating topographical maps...\n');
% figure('Name', 'EEG Topographical Maps', 'Position', [100 100 1200 800]);

% % Get unique time points (sample every 100ms)
% time_points = unique(final_dc.time);
% time_points = time_points(1:10:end);  % Sample every 10th point

% % Create subplots for each time point
% num_time_points = length(time_points);
% for i = 1:num_time_points
%     subplot(2, ceil(num_time_points/2), i);
    
%     % Get data for current time point
%     time_data = final_dc(final_dc.time == time_points(i), :);
    
%     % Create topographical map
%     topoplot(time_data.mean_value, time_data.channel, 'style', 'map', 'electrodes', 'on');
%     title(sprintf('Time: %.2f s', time_points(i)));
%     colorbar;
% end

fprintf('Visualization complete!\n');
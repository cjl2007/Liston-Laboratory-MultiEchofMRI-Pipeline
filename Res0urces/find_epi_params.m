
% turn off
% warnings
warning off;

% clean slate;
system(['rm -rf ' Subdir '/func/xfms/rest/']);
system(['rm -rf ' Subdir '/func/rest/']);

count = 0; % preallocate

% count the number of sessions;
sessions = dir([Subdir '/func/unprocessed/rest/session_*']);

% sweep the sessions;
for s = 1:length(sessions)
    
    % count the number of runs;
    runs = dir([Subdir '/func/unprocessed/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)
        
        % make the dir.
        system(['mkdir -p ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/']);
        
        count = count+1;
        
        % define json dir.
        json_dir = ([Subdir '/func/unprocessed/rest/session_' num2str(s) '/run_' num2str(r) '/']);
        
        % find .json file
        json = dir([json_dir '/Rest*.json']);
        
        % preallocate
        te = zeros(1,length(json));
        
        % sweep the echoes;
        for e = 1:length(json)
            
            % load data
            j = loadjson([json_dir '/'...
                json(e).name]);
            
            % echo times;
            te(e) = j.EchoTime*10^3; % convert to ms
            
        end
        
        % extract the TR;
        tr(count) = j.RepetitionTime;
        
        % (effective) echo spacing;
        es(count) = j.EffectiveEchoSpacing;

        % load data
        j = loadjson([json_dir '/'...
            json(1).name]);
        
        % extract slice timing
        slice_times = j.SliceTiming;
        
        % calculate slice order
        [x,slice_order] = sort(slice_times(1:length(unique(slice_times))));
        ref_slice = slice_order(round(length(slice_order)/2)); % select the "reference slice"; i.e., the slice with no slice time correction
        
        % preallocate the output
        timing_file = zeros(length(slice_order),1);
        
        % sweep TRs;
        for i = 1:length(slice_order)
            timing_file(i) = (find(slice_order==ref_slice) - find(slice_order==i)) / length(slice_order);
        end
        
        % factor in multi-band acc; if needed
        if isfield(j,'MultibandAccelerationFactor')
            timing_file = repmat(timing_file,j.MultibandAccelerationFactor,1);
        end
        
        % sweep the remaining TRs
        for i = 1:length(timing_file)
            system(['echo ' num2str(timing_file(i)) ' >> ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/slice_times.txt']);
        end
        
        % write out some other files;
        system(['echo ' num2str(te) ' > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/te.txt']);
        system(['echo ' num2str(tr(count)) ' > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/tr.txt']);
        system(['echo ' num2str(es(count)) ' > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/es.txt']);

    end
    
end

% make "qa" and "xfms" folders;
system(['mkdir -p ' Subdir '/func/qa/']);
system(['mkdir -p ' Subdir '/func/xfms/rest/']);

count = 0; % preallocate;

% sweep all the sessions
for s = 1:length(sessions)
    
    % count the number of runs;
    runs = dir([Subdir '/func/unprocessed/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)

        count = count + 1; % tick
        te = load([Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/te.txt']);
        system(['echo Session ' num2str(s) ' Run ' num2str(r) ': ' num2str(te) ' >> ' Subdir '/func/qa/AllTEs.txt']);
        system(['echo Session ' num2str(s) ' Run ' num2str(r) ': ' num2str(tr(count)) ' >> ' Subdir '/func/qa/AllTRs.txt']);

    end
    
end

% log effective echo spacing (used during corrections for spatial distortions);
system(['echo ' num2str(mode(es)) ' >> ' Subdir '/func/xfms/rest/EffectiveEchoSpacing.txt']);



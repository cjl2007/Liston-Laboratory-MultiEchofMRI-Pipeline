function calc_fd_func(Subdir,sessions)

% add resources;
addpath(genpath('/home/charleslynch/res0urces'));

% define
% the number
% of sessions;
if isempty(sessions)
    sessions = dir([Subdir '/func/rest/session_*']);
end

% sweep the sessions
for s = 1:length(sessions)
    
    % count the number of runs for this session;
    runs = dir([Subdir '/func/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)
        
        % load mcflirt parameters (assumed that first three columns
        % are rotation in radians and then last three are translation)
        rp = load([Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/MCF.par']);
        
        % calculate frame-wise displacement
        % (1-4 TRs; no band stop filter applied)
        
        % sweep trs
        for f = 1:4
            
            fd_temp = rp; % preallocate
            fd_temp(1:f,:) = 0; % by convention
            
            % calculate
            % backward
            % difference;
            for i = 1:size(rp,2)
                for ii = (f+1):size(fd_temp,1)
                    fd_temp(ii,i) = abs(rp(ii,i)-rp(ii-f,i));
                end
            end
            
            fd_ang = fd_temp(:,1:3); % convert rotation columns into angular displacement...
            fd_ang = fd_ang / (2 * pi); % fraction of circle
            fd_ang = fd_ang * 100 * pi; % multiplied by circumference
            fd_temp(:,1:3) = []; % delete rotation columns,
            fd_temp = [fd_temp fd_ang]; % add back in as angular displacement
            fd_temp = sum(fd_temp,2); % sum
            
            % log data
            Motion.fd.(['no_filt_' num2str(f) 'TR']) = fd_temp;
            
        end
        
        % calculate some respiration-related information
        
        TR = load([Subdir '/func/rest/session_'...
            num2str(s) '/run_' num2str(r) '/TR.txt']);
        
        % nyquist freq.
        nyq = (1/TR)/2;
        
        % if;
        if nyq > 0.4
            % create a tailored
            % stop band filter;
            stopband = [0.2 0.4];
            [B,A] = butter(10,stopband/nyq,'stop');
        else
            % create a tailored
            % stop band filter;
            stopband = [0.2 (nyq-0.019)];
            [B,A] = butter(10,stopband/nyq,'stop');
        end
        
        % save stop band information;
        Motion.power.stopband = stopband;
        
        % sweep through rps;
        for i = 1:size(rp,2)
            [pw,pf] = pwelch(rp(:,i),[],[],[],1/TR,'power');
            idx = find(pf<nyq & pf>0.05);
            Motion.power.no_filt.pf(:,i) = pf(idx); % note: should be six identical columns
            Motion.power.no_filt.pw(:,i) = pw(idx);
        end
        
        % apply stop-
        % band filter;
        for i = 1:size(rp,2)
            rp(:,i) = filtfilt(B,A,rp(:,i));
        end
        
        % sweep through rps;
        for i = 1:size(rp,2)
            [pw,pf] = pwelch(rp(:,i),[],[],[],1/TR,'power');
            idx = find(pf<nyq & pf>0.05);
            Motion.power.filt.pf(:,i) = pf(idx); % note: should be six identical columns
            Motion.power.filt.pw(:,i) = pw(idx);
        end
        
        % frame-wise displacement (1 TR; band stop filter applied)
        
        % sweep trs;
        for f = 1:4
            
            fd_temp = rp; % preallocate
            fd_temp(1:f,:) = 0; % by convention
            
            % calculate
            % backward
            % difference;
            for i = 1:size(rp,2)
                for ii = (f+1):size(fd_temp,1)
                    fd_temp(ii,i) = abs(rp(ii,i)-rp(ii-f,i));
                end
            end
            
            fd_ang = fd_temp(:,1:3); % convert rotation columns into angular displacement...
            fd_ang = fd_ang / (2 * pi); % fraction of circle
            fd_ang = fd_ang * 100 * pi; % multiplied by circumference
            fd_temp(:,1:3) = []; % delete rotation columns,
            fd_temp = [fd_temp fd_ang]; % add back in as angular displacement
            fd_temp = sum(fd_temp,2); % sum
            
            % log data
            Motion.fd.(['filt_' num2str(f) 'TR']) = fd_temp;
            
        end
        
        % save "master" Motion variable
        save([Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/Motion'],'Motion');
        
        
        
      
    end
    
    
end

end
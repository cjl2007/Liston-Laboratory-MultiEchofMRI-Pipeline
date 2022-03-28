
% infer subject name;
Subject = strsplit(Subdir,'/');
Subject = Subject{length(Subject)};

% make sure figures are suppressed;
set(0,'DefaultFigureVisible','off');

% define the number of sessions;
sessions = dir([Subdir '/func/rest/session_*']);

% sweep the scans;
for s = 1:length(sessions)
    
    % this is the number of runs for this session;
    runs = dir([Subdir '/func/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)
        
        % first, we calculate a bunch of head movement related metrics;

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
        save([Subdir '/func/rest/session_' num2str(s)...
        '/run_' num2str(r) '/Motion'],'Motion');
        
        % read in some information about this run
        echoes = load([Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/TE.txt']); % te
        tr = load([Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/TR.txt']); % tr
        nyq = (1/tr)/2;
        
        % sweep trs
        for i = 1:4
            tmp(i) = abs(floor(i*tr)-2);
        end
        
        % find the relevant number
        % of TRs for FD calculation;
        fd_trs = find(tmp==min(tmp));
        
        % clear;
        clear tmp
        
        % load unfiltered realignment parameters;
        rp_no_filt = load([Subdir '/func/rest/session_'...
        num2str(s) '/run_' num2str(r) '/MCF.par']);
        
        % calculate frame-wise displacement;
        [fd,rp_filt] = calc_fd(rp_no_filt,tr);
        
        % convert rotation columns
        % into angular displacement;
        rp_no_filt(:,1:3) = rp_no_filt(:,1:3) * 50;
        rp_filt(:,1:3) = rp_filt(:,1:3) * 50;
        
        % make sure figures are suppressed;
        %set(0,'DefaultFigureVisible','off');
        
        % read in original data;
        for e = 1:length(echoes)
            all_data{e} = single(niftiread([Subdir '/func/rest/session_'...
            num2str(s) '/run_' num2str(r) '/Rest_E' num2str(e) '_acpc.nii.gz']));
        end
        
        % set dims;
        dims = size(all_data{1});
        
        % now, the main loop
        
        % define
        % some bins
        count = 0;
        for i = 1:ceil(dims(4)/(300/tr))
            for ii = 1:ceil((300/tr))
                count=count+1;
                bins(i,ii)=count;
            end
        end
        
        H = figure; % prellocate parent figure
        set(H,'position',[1 1 850 750],'Color','w');
        
        count = 0; % tic
        
        % sweep time;
        for i = 1:dims(4)
            
            % respiration;
            subaxis(6,3,[10 11 12],'MB',0.05,'MT',0.05,'ML',0.05,'MR',0.05);
            
            % check if physio data exists;
            scout = dir([Subdir '/physio/unprocessed/rest/session_'...
            num2str(s) '/run_' num2str(r) '/*RESP*']);
            
            % if available;
            if ~isempty(scout)
                
                % parse physio data;
                resp = extract_resp([Subdir '/physio/unprocessed/rest/session_'...
                num2str(s) '/run_' num2str(r) '/'],50);
                
                % plot respiration power spectra;
                [pw,pf] = pwelch(resp,[],[],[],50,'power');
                
                % smooth data;
                smoothdata(pw);
                
                % trim spectra;
                idx = find(pf<nyq & pf>0.05);
                pw = pw(idx);
                pf = pf(idx);
                
                % find global max;
                resp_peak = pf(pw==max(pw));
                resp_peak = resp_peak(1);
                
                % downresample respiration trace;
                resp = resp(round(linspace(1,length(resp),dims(4)))); % old methold
                
                % plot respiration;
                plot(zscore(resp),'b');
                
                % set y limits;
                ylim([-3 3]);
                
                % remove labels;
                yticklabels('');
                ylabel('');
                xlabel('');
                xticks('');
                
                % set font size and title;
                set(gca,'FontName','Arial','FontSize',10,'TickLength',[0 0]);
                title(['Respiration Belt (Peak Power: ' num2str(round(resp_peak*100)) 'Hz)']);
                
                % add vline;
                vline(i,'k');
                time=seconds(i*tr);
                time.Format='mm:ss.SSSS';
                time = char(time);
                time = time(1:end-5);
                
                % find "i" in bins variable;
                [row,col] = find(bins==i);
                
                % adjust x limits accordingly;
                xlim([bins(row,1) bins(row,end)]);
                
                % left/right of vline?
                if col < size(bins,2)/2
                    text(col/size(bins,2),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
                else
                    text((col/size(bins,2)-.05),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
                end
                
            else
                
                % add vline;
                vline(i,'k');
                time=seconds(i*tr);
                time.Format='mm:ss.SSSS';
                time = char(time);
                time = time(1:end-5);
                
                % find "i" in bins variable;
                [row,col] = find(bins==i);
                
                % adjust x limits accordingly;
                xlim([bins(row,1) bins(row,end)]);
                
                % left vs. right
                % side of vline
                if col < size(bins,2)/2
                    text(col/size(bins,2),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
                else
                    text((col/size(bins,2)-.05),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
                end
                
                % blank graph
                ylabel('');
                yticklabels('');
                xlabel('');
                xticks('');
                
                % set font information and title;
                set(gca,'FontName','Arial','FontSize',10,'TickLength',[0 0]);
                title('Respiration Belt Not Available');
                
            end
            
            % plot original (unfiltered) head Motion parameters;
            subaxis(6,3,[13 14 15],'MB',0.05,'MT',0.05,'ML',0.05,'MR',0.05);
            l = plot(rp_filt-rp_filt(1,:),'LineWidth',1);
            
            % set line colors
            l(1).Color = [216 65 35 255]/255;
            l(2).Color = [152 252 128 255]/255;
            l(3).Color = [55 58 245 255]/255;
            l(4).Color = [143 252 254 255]/255;
            l(5).Color = [235 98 247 255]/255;
            l(6).Color = [232 233 122 255]/255;
            
            % set initial
            % y limits
            ylim([-.5 .5]);
            xticks('');
            
            % set font size and subaxis title;
            set(gca,'FontName','Arial','FontSize',10,'TickLength',[0 0]);
            title(['Filtered (Stopband: ' num2str(round(Motion.power.stopband(1)*100)) '-' num2str(round(Motion.power.stopband(2)*100)) 'Hz) Realignment Parameters (mm)']);
            
            % adjust x limits accordingly;
            xlim([bins(row,1) bins(row,end)]);
            
            % define epoch
            epoch = xlim;
            
            % trim; if needed;
            if epoch(2) > size(rp_no_filt,1)
                epoch(2) = size(rp_no_filt,1);
            end
            
            % expand ylim; if needed.
            while max(abs(ylim)) < max(max(abs(rp_no_filt(epoch(1):epoch(2),:)-rp_no_filt(1,:))))
                ylim([ ylim + [-.5 .5] ]);
            end
            
            % add vline;
            vline(i,'k');
            
            % tack on the legend;
            legend({'Yaw','Pitch','Roll','X','Y','Z'},'Location','SouthEast','Orientation','horizontal','FontSize',10);
            legend('boxoff'); % turn the box off;
            
            % left vs. right
            % side of vline
            if col < size(bins,2)/2
                text(col/size(bins,2),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
            else
                text((col/size(bins,2)-.05),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
            end
            
            % framewise displacement subaxis;
            subaxis(6,3,[16 17 18],'MB',0.05,'MT',0.05,'ML',0.05,'MR',0.05);
            plot(Motion.fd.(['filt_' num2str(fd_trs) 'TR']),'Color','r');
            
            % set initial
            % y limits
            ylim([0 1]);
            
            hline(.2,'--k'); % this is the scrubbing threshold;
            xticks('');
            
            % set font size and subaxis title;
            set(gca,'FontName','Arial','FontSize',10,'TickLength',[0 0]);
            title(['Framewise Displacement (' num2str(fd_trs) 'TRs; mm)']);
            
            % adjust x limits accordingly;
            xlim([bins(row,1) bins(row,end)]);
            
            % define epoch
            epoch = xlim;
            
            % trim; if needed;
            if epoch(2) > length(dims(4))
                epoch(2) = length(dims(4));
            end
            
            % create a temporary variable ("x");
            x = Motion.fd.(['filt_' num2str(fd_trs) 'TR']);
            x(epoch(1):epoch(2));
            
            % expand ylim; if needed.
            while max(ylim) < max(x)
                ylim([ ylim + [0 .5] ]);
            end
            
            % add vline;
            vline(i,'k');
            
            % left vs. right
            % side of vline
            if col < size(bins,2)/2
                text(col/size(bins,2),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
            else
                text((col/size(bins,2)-.05),0.9,time,'Units','normalized','Color','black','FontSize',9,'FontName','Arial');
            end
            
            % sweep the echoes;
            for e = 1:length(echoes)
                
                % extract echo "e"
                data = all_data{e};
                
                % extract the slices;
                a = flip(squeeze(data(:,round(dims(2)/2),:,i)),2)';
                b = flip(squeeze(data(round(dims(1)/2),:,:,i)),2)';
                c = flip(squeeze(data(:,:,round(dims(3)/2),i)),2)';
                
                % count rows;
                rows(1) = size(a,1);
                rows(2) = size(b,1);
                rows(3) = size(c,1);
                
                % max number of rows;
                n_rows = max(rows);
                
                % adjust a; if needed
                if n_rows > rows(1)
                    a = [zeros(round(abs(n_rows-rows(1)) / 2),size(a,2)) ; a ; zeros(abs(round(abs(n_rows-rows(1)) / 2)-(abs(n_rows-rows(1)))),size(a,2))];
                end
                
                % adjust b; if needed
                if n_rows > rows(2)
                    b = [zeros(round(abs(n_rows-rows(2)) / 2),size(b,2)) ; b ; zeros(abs(round(abs(n_rows-rows(2)) / 2)-(abs(n_rows-rows(2)))),size(b,2))];
                end
                
                % adjust c; if needed
                if n_rows > rows(2)
                    c = [zeros(round(abs(n_rows-rows(3)) / 2),size(c,2)) ; c ; zeros(abs(round(abs(n_rows-rows(3)) / 2)-(abs(n_rows-rows(3)))),size(c,2))];
                end
                
                % plot the data;
                subaxis(6,3,1:9,'MB',0.05,'MT',0.05,'ML',0.05,'MR',0.05);
                
                % plot image;
                imagesc([a b c]); colormap(gray); axis 'off'
                
                % define some horizontal and vertical lines
                vl = round(linspace(1,size([a b c],2),10));
                
                % apply vertical lines
                for ii = 1:length(vl)
                    vline(vl(ii),'r')
                end
                
                % define some horizontal lines
                hl = round(linspace(1,size([a b c],1),round(10*(size([a b c],1)/size([a b c],2)))));
                
                % apply horizontal lines
                for ii = 1:length(hl)
                    hline(hl(ii),'r')
                end
                
                % apply some text now;
                text(0.01,0.05,['Min. Preprocessed TR (' num2str(tr*10^3) 'ms): ' num2str(i) '/' num2str(dims(4))],'Units','normalized','Color','white','FontSize',14,'FontName','Arial');
                text(0.01,0.11,['TE' num2str(e) ': ' num2str(echoes(e)) 'ms'],'Units','normalized','Color','white','FontSize',14,'FontName','Arial');
                text(0.01,0.95,[Subject ' Session: ' num2str(s) ', Run: ' num2str(r)],'Units','normalized','Color','white','FontSize',14,'FontName','Arial');
                
                % log frame
                count = count+1;
                m(count) = getframe(H);
                
            end
            
            hold off; % turn off hold;
            
        end
        
        % create movie;
        v = VideoWriter([Subdir '/func/qa/MotionQA/MotionQA_Movie_S' num2str(s) '_R' num2str(r)]);
        v.FrameRate = 10;
        v.Quality = 100; % max quality
        open(v);
        writeVideo(v,m);
        close(v);
        close all
        
    end
    
    
end

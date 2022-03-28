
% infer subject name;
Subject = strsplit(Subdir,'/');
Subject = Subject{length(Subject)};

% this is the brain mask in functional volume space;
BrainMask = niftiread([Subdir '/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz']);

% this is the target image (the average SBref image in ACPC volume space);
TargetImage = niftiread([Subdir '/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.nii.gz']);

% define the number of sessions;
sessions = dir([Subdir '/func/rest/session_*']);

count = 0; % tick

% sweep the scans;
for s = 1:length(sessions)
    
    % this is the number of runs for this session;
    runs = dir([Subdir '/func/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)
        
        % tick
        count = count+1;

        % extract the SBref coregistered to target volume using average field map information;
        Volume = niftiread([Subdir '/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_AvgFM_S' num2str(s) '_R' num2str(r) '.nii.gz']);
        
        % log spatial correlation;
        Rho(count,1) = corr(Volume(BrainMask==1),TargetImage(BrainMask==1),'type','Spearman');
        
        % if scan-specific field map exists; otherwise use NaN place-holder;
        if exist([Subdir '/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_ScanSpecificFM_S' num2str(s) '_R' num2str(r) '.nii.gz'])
            Volume = niftiread([Subdir '/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_ScanSpecificFM_S' num2str(s) '_R' num2str(r) '.nii.gz']);
            Rho(count,2) = corr(Volume(BrainMask==1),TargetImage(BrainMask==1),'type','Spearman');
        else
            Rho(count,2) = nan;
        end
        
        % check which approach works best;
        if Rho(count,1) > Rho(count,2) || isnan(Rho(count,2))
            system(['echo ' Subdir '/func/xfms/rest/AvgSBref.nii.gz > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/IntermediateCoregTarget.txt']);
            system(['echo ' Subdir '/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/Intermediate2ACPCWarp.txt']);
        else
            system(['echo ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/SBref.nii.gz > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/IntermediateCoregTarget.txt']);
            system(['echo ' Subdir '/func/xfms/rest/SBref2acpc_EpiReg+BBR_S' num2str(s) '_R' num2str(r) '_warp.nii.gz > ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/Intermediate2ACPCWarp.txt']);
        end

    end
    
end

H = figure; % prellocate parent figure
set(H,'position',[1 1 674 435],'Color','w');

count = 0; % tic

% max co-reg quality;
MaxRho = max(Rho,[],2);

% make sure figures are suppressed;
set(0,'DefaultFigureVisible','off');

% sweep the scans;
for s = 1:length(sessions)
    
    % this is the number of runs for this session;
    runs = dir([Subdir '/func/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)
        
        count = count+1; % tick;

        % first subplot
        subaxis(3,1,1,'MB',0.05,'MT',0.05,'ML',0.1,'MR',0.05);
        plot(MaxRho,'k'); hold;
        ylim([0.8 1]);
        scatter(count,MaxRho(count),750,'r','.')
        set(gca,'FontName','Arial','FontSize',10,'TickLength',[0 0]);
        ylabel('Correlation with Avg. SBref');
        xticklabels('');
        box 'off'
        hold off;
        
        % extract the mean volume;
        if Rho(count,1) > Rho (count,2) || isnan(Rho(count,2))
        SBref = niftiread([Subdir '/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_AvgFM_S' num2str(s) '_R' num2str(r) '.nii.gz']);
        else
        SBref = niftiread([Subdir '/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_ScanSpecificFM_S' num2str(s) '_R' num2str(r) '.nii.gz']);
        end
        
        % remove skull;
        SBref(BrainMask==0)=0;
  
        % get the dimensions;
        dims = size(SBref);
        
        % extract the slices;
        a = flip(squeeze(SBref(:,round(dims(2)/2),:,1)),2)';
        b = flip(squeeze(SBref(round(dims(1)/2),:,:,1)),2)';
        c = flip(squeeze(SBref(:,:,round(dims(3)/2),1)),2)';
        
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
        
        % plot image;
        subaxis(3,1,[2 3],'MB',0.05,'MT',0.05,'ML',0.1,'MR',0.05);
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
        text(0.01,0.88,['Average SBref Volume'],'Units','normalized','Color','white','FontSize',14,'FontName','Arial');
        text(0.01,0.95,[Subject ' Session: ' num2str(s) ', Run: ' num2str(r)],'Units','normalized','Color','white','FontSize',14,'FontName','Arial');
        
        % log frame
        m(count) = getframe(H);
   
    end
    
end

% create movie;
v = VideoWriter([Subdir '/func/qa/CoregQA/CoregQA_Movie']);
v.FrameRate = 10;
v.Quality = 100; % max quality
open(v);
writeVideo(v,m);
close(v);
close all

% save Rho variable
save([Subdir '/func/qa/CoregQA/Rho'],'Rho');

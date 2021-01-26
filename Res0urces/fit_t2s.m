
% add resources;
addpath(genpath(resources));

% clean dir.
system(['rm -rf ' Subdir '/func/t2star/']);
system(['mkdir ' Subdir '/func/t2star/']);

% define the number of sessions;
sessions = dir([Subdir '/func/rest/session_*']);

% load echo times;
te = load([Subdir '/func/rest/session_1/run_1/te.txt']); % lets assume that all scans have the same te; this may not be true in practice; user beware.
te = double(te); % convert to double

% create and load a brain mask;
mask = niftiread([Subdir '//func/xfms/rest/T1w_acpc_brain_2mm_mask.nii.gz']);
dims = size(mask); % data dims;
mask = reshape(mask,[dims(1)*dims(2)*dims(3),1]);
brain_voxels = find(mask==1); % define all in-brain voxels;

% read in example header information;
info = niftiinfo([Subdir '/func/xfms/rest/T1w_acpc_brain_2mm_mask.nii.gz']);

% start parpool;
pool = parpool('local',ncores);

% sweep the scans;
for s = 1:length(sessions)
    
    % this is the number of runs for this session;
    runs = dir([Subdir '/func/rest/session_' num2str(s) '/run_*']);
    
    % sweep the runs;
    for r = 1:length(runs)

        % sweep the TE
        parfor i = 1:length(te)
           
            % calculate a temporal average;
            system(['fslmaths ' Subdir '/func/rest/session_' num2str(s) '/run_' num2str(r) '/Rest_E' num2str(i) '_acpc.nii.gz -Tmean ' Subdir '/workspace/temp_e' num2str(i) '_s' num2str(s) '_r' num2str(r) '.nii.gz']); 

        end

    end

end

% sweep the TE
parfor i = 1:length(te)
    
    % merge all of the individual echoes;
    system(['fslmerge -t ' Subdir '/workspace/temp_avg_e' num2str(i) '.nii.gz ' Subdir '/workspace/temp_e' num2str(i) '*.nii.gz']);
    
    % average across all echoes;
    system(['fslmaths ' Subdir '/workspace/temp_avg_e' num2str(i) '.nii.gz -Tmean ' Subdir '/workspace/temp_avg_e' num2str(i) '.nii.gz']);
    
    % read in the .nii
    nii = niftiread([Subdir '/workspace/temp_avg_e' num2str(i) '.nii.gz']); 
    
    % data dims;
    dims = size(nii); 
    
    % log this average echo;
    data(:,i) = reshape(double(nii),[dims(1)*dims(2)*dims(3),1]);
    
end

% move "average TEs" image to t2s dir.;
system(['fslmerge -t ' Subdir '/func/t2star/Avg_TEs.nii.gz ' Subdir '/workspace/temp_avg_e*.nii.gz']);
    
% turn off
% annoying warnings
warning('off','all');

% S = S0 * exp(-t * R2*)
mefun = @(b,x)(b(1)*exp(-b(2)*x));

% sweep all in-brain voxels;
parfor i = 1:length(brain_voxels)
    
    % dont trust this voxel if signal
    % is not decreasing across echoes;
    if issorted(data(brain_voxels(i),:),'descend')
        
        % fit a monoexponential decay model (slower but more accurate);
        [b_init] = regress(log(abs(data(brain_voxels(i),:))+1)',[ones(length(te),1) (te*-1)']); % use log-lin fit as initial guess;
        mdl = fitnlm(te,data(brain_voxels(i),:),mefun,[data(brain_voxels(i),1) b_init(2)]);
        
        % log values;
        a(i) = 1 / mdl.Coefficients.Estimate(2); % note: T2* = 1 / R2*
        b(i) = mdl.Rsquared.Adjusted; % R2
        
    else
        
        % log "place-
        % holder" values;
        a(i) = 0; % T2*
        b(i) = 0; % R2
        
    end
    
end

% preallocate
% output variables;
t2s = zeros(size(mask));
gof = zeros(size(mask)); 

% log values from parfor loop;
t2s(brain_voxels) = a; % T2*
gof(brain_voxels) = b; % R2

% adjust header info;
info.Datatype='double';
info.BitsPerPixel = 64;

% cap "extreme" values
t2s(t2s > 500) = 0; % this cutoff is used by tedana.
t2s(t2s < 0) = 0; % remove negative values 
t2s(gof < 0.8) = 0; % remove "bad" fits;

% reshape, write, and compress t2s map;
t2s = reshape(t2s,[dims(1),dims(2),dims(3)]);
niftiwrite(t2s,[Subdir '/func/t2star/T2star_acpc'],info);
system(['gzip -f ' Subdir '/func/t2star/T2star_acpc.nii']);

% reshape, write, and compress t2s map;
gof = reshape(gof,[dims(1),dims(2),dims(3)]);
niftiwrite(gof,[Subdir '/func/t2star/R2_acpc'],info);
system(['gzip -f ' Subdir '/func/t2star/R2_acpc.nii']);

% fill in bad values;
system(['wb_command -volume-dilate ' Subdir '/func/t2star/T2star_acpc.nii.gz 10 NEAREST  ' Subdir '/func/t2star/T2star_acpc.nii.gz -data-roi ' Subdir '/func/xfms/rest/T1w_acpc_brain_2mm.nii.gz']);

% now, oc-me

% create and load a brain mask;
t2s = niftiread([Subdir '/func/t2star/T2star_acpc.nii.gz']);
dims = size(t2s); % data dims;
t2s = reshape(t2s,[dims(1)*dims(2)*dims(3),1]);

% load all the average echoes;
data = niftiread([Subdir '/func/t2star/Avg_TEs.nii.gz']);
dims = size(data); % data dims;
data = reshape(data,[dims(1)*dims(2)*dims(3),dims(4)]);

% preallocate weights for te;
wte = zeros(size(data,1),length(te));

% sweep all points in the brain;
for i = 1:length(brain_voxels)
    
    % sweep through te
    for ii = 1:length(te)
        wte(brain_voxels(i),ii) = te(ii) * exp( ( te(ii) * -1 ) / t2s(brain_voxels(i)) );
    end
    
    % normalize weights accross te;
    wte(brain_voxels(i),:) = wte(brain_voxels(i),:) / norm(wte(brain_voxels(i),:),1);
     
end

% combine the images using weights;
oc_me = reshape(sum( double(wte) .* double(data) , 2),[dims(1),dims(2),dims(3),1]);

% write out non-optimally combined image and weights; 
niftiwrite(oc_me,[Subdir '/func/t2star/OCME'],info);
system(['gzip -f ' Subdir '/func/t2star/OCME.nii']); % zip oc-me file; 

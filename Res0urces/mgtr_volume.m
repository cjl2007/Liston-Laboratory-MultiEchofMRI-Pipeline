% read in mask and define all "in-brain" voxels;
mask = niftiread([Subdir '/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz']);
info_3D = niftiinfo([Subdir '/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz']); % nii info; used for writing the output.
dims = size(mask); % mask dims;
mask = reshape(mask,[dims(1)*dims(2)*dims(3),1]);
brain_voxels = find(mask==1); % define all in-brain voxels;

% adjust header info;
info_3D.Datatype = 'double';
info_3D.BitsPerPixel = 64;

% load input data;
data = niftiread(Input);
dims = size(data); % data dims;
data = reshape(data,[dims(1)*dims(2)*dims(3),dims(4)]);
info_4D = niftiinfo(Input); % nii info; used for writing the output.
data_mean = mean(data,2); % hold onto this for a moment...

% create cortical ribbon file; if needed
if ~exist([Subdir '/func/rois/CorticalRibbon.nii.gz'],'file')
    str = strsplit(Subdir,'/'); Subject = str{end}; % infer subject name
    system(['mri_convert -i ' Subdir '/anat/T1w/' Subject '/mri/lh.ribbon.mgz -o ' Subdir '/func/rois/lh.ribbon.nii.gz --like ' Subdir '/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz > /dev/null 2>&1']);
    system(['mri_convert -i ' Subdir '/anat/T1w/' Subject '/mri/rh.ribbon.mgz -o ' Subdir '/func/rois/rh.ribbon.nii.gz --like ' Subdir '/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz > /dev/null 2>&1']);
    system(['fslmaths ' Subdir '/func/rois/lh.ribbon.nii.gz -add ' Subdir '/func/rois/rh.ribbon.nii.gz ' Subdir '/func/rois/CorticalRibbon.nii.gz > /dev/null 2>&1']);
    system(['fslmaths ' Subdir '/func/rois/CorticalRibbon.nii.gz -bin ' Subdir '/func/rois/CorticalRibbon.nii.gz']);
    system(['rm ' Subdir '/func/rois/*.ribbon.*']); % clean up;
end

% read in mask and define all "in-brain" voxels;
gray = niftiread([Subdir '/func/rois/CorticalRibbon.nii.gz']);
gray = reshape(gray,[dims(1)*dims(2)*dims(3),1]);

% calculate the global signal;
gs = mean(data(gray==1,:));

% preallocate betas;
b = zeros(size(data,1),1);

% sweep all in-brain voxels;
for i = 1:length(brain_voxels)
    
    % remove the mean gray matter signal;
    [betas,~,data(brain_voxels(i),:),~,~] = regress(data(brain_voxels(i),:)',[gs' ones(length(gs),1)]); % could consider adding first-order temporal deriv. 
    b(brain_voxels(i)) = betas(1); % log the gs beta;
    
end

% reshape, write, and compress ocme+meica+mgtr time-series
data = reshape(data + data_mean,[dims(1),dims(2),dims(3),dims(4)]); % add the temporal mean back in; 
info_4D.Filename = Output_MGTR;
system(['rm ' Output_MGTR '*']);
niftiwrite(data,Output_MGTR,info_4D);
system(['gzip ' Output_MGTR '.nii']);

% reshape, write, and compress beta map;
b = reshape(b,[dims(1),dims(2),dims(3),1]);
info_3D.Filename = Output_Betas;
system(['rm ' Output_Betas '*']);
niftiwrite(b,Output_Betas,info_3D);
system(['gzip ' Output_Betas '.nii']);



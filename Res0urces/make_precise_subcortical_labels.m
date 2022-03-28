
Labels = [8 47 26 58 18 54 11 50 17 53 13 52 12 51 10 49 16 28 60]; % these are the default subcortical labels;
tmp_dir = [Subdir '/func/rois/tmp/']; % define the roi directory
system(['mkdir -p ' tmp_dir]); % make the temporary dir. 
cd(tmp_dir); % change dir. 

% sweep through the labels
for i = 1:length(Labels)

system(['mri_binarize --i ' Subdir '/anat/T1w/aparc+aseg.nii.gz  --match ' num2str(Labels(i)) ' --o ' tmp_dir '/Label' num2str(i) '.nii.gz']);
system(['flirt -interp trilinear -in ' tmp_dir '/Label' num2str(i) '.nii.gz -ref ' AtlasTemplate ' -applyxfm -init /home/charleslynch/MultiEchofMRI-Pipeline/res0urces/ident.mat -out ' tmp_dir '/Label' num2str(i) '_Interp.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp.nii.gz -thr 0.6 ' tmp_dir '/Label' num2str(i) '_Interp_Thresh.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp_Thresh.nii.gz -bin ' tmp_dir '/Label' num2str(i) '_Interp_Thresh_Bin.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp_Thresh_Bin.nii.gz -mul ' num2str(Labels(i)) ' ' tmp_dir '/Label' num2str(i) '_Final.nii.gz']);

end

% merge the files;
system(['fslmerge -t ' tmp_dir '/FinalLabels.nii.gz ' tmp_dir '/Label*_Final.nii.gz']);
system(['fslmaths ' tmp_dir '/FinalLabels.nii.gz -Tmax ' tmp_dir '/FinalLabels.nii.gz']);
system(['wb_command -volume-label-import ' tmp_dir '/FinalLabels.nii.gz ' SubcorticalLabels ' ' Subdir '/func/rois/Subcortical_ROIs_acpc.nii.gz -discard-others']);
system(['rm -rf ' tmp_dir]);

% MNInonlinear;

tmp_dir = [Subdir '/func/rois/tmp/']; % define the roi directory
system(['mkdir -p ' tmp_dir]); % make the temporary dir. 
cd(tmp_dir); % change dir. 

% sweep through the labels
for i = 1:length(Labels)

system(['mri_binarize --i ' Subdir '/anat/MNINonLinear/aparc+aseg.nii.gz  --match ' num2str(Labels(i)) ' --o ' tmp_dir '/Label' num2str(i) '.nii.gz']);
system(['flirt -interp trilinear -in ' tmp_dir '/Label' num2str(i) '.nii.gz -ref ' AtlasTemplate ' -applyxfm -init /home/charleslynch/MultiEchofMRI-Pipeline/res0urces/ident.mat -out ' tmp_dir '/Label' num2str(i) '_Interp.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp.nii.gz -thr 0.6 ' tmp_dir '/Label' num2str(i) '_Interp_Thresh.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp_Thresh.nii.gz -bin ' tmp_dir '/Label' num2str(i) '_Interp_Thresh_Bin.nii.gz']);
system(['fslmaths ' tmp_dir '/Label' num2str(i) '_Interp_Thresh_Bin.nii.gz -mul ' num2str(Labels(i)) ' ' tmp_dir '/Label' num2str(i) '_Final.nii.gz']);

end

% merge the files;
system(['fslmerge -t ' tmp_dir '/FinalLabels.nii.gz ' tmp_dir '/Label*_Final.nii.gz']);
system(['fslmaths ' tmp_dir '/FinalLabels.nii.gz -Tmax ' tmp_dir '/FinalLabels.nii.gz']);
system(['wb_command -volume-label-import ' tmp_dir '/FinalLabels.nii.gz ' SubcorticalLabels ' ' Subdir '/func/rois/Subcortical_ROIs_nonlin.nii.gz -discard-others']);
system(['rm -rf ' tmp_dir]);

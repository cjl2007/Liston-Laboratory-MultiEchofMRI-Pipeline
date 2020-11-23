#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
SUBJECTS_DIR="$Subdir"/anat/T1w/ # note: this is used for "bbregister" calls;

# create a white matter segmentation (.mgz --> .nii.gz);
mri_binarize --i "$Subdir"/anat/T1w/"$Subject"/mri/aparc+aseg.mgz --wm --o "$Subdir"/anat/T1w/"$Subject"/mri/white.mgz > /dev/null 2>&1  
mri_convert -i "$Subdir"/anat/T1w/"$Subject"/mri/white.mgz -o "$Subdir"/anat/T1w/"$Subject"/mri/white.nii.gz --like "$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz > /dev/null 2>&1   # create a white matter segmentation (.mgz --> .nii.gz);

# build a list of all the field maps;
ap_fms=("$Subdir"/func/unprocessed/field_maps/AP_*.nii.gz)
pa_fms=("$Subdir"/func/unprocessed/field_maps/PA_*.nii.gz)

# create & define the average FM directory;
mkdir -p "$Subdir"/func/field_maps/AverageFM > /dev/null 2>&1
WDIR="$Subdir"/func/field_maps/AverageFM

# create clean tmp. copy of freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1 
cp -rf "$Subdir"/anat/T1w/"$Subject" "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1

prep_field_maps () {

	# copy over field map "i" to workspace 
	cp "${ap_fms[$i]}" "$WDIR"/"$i"_AP.nii.gz
	cp "${pa_fms[$i]}" "$WDIR"/"$i"_PA.nii.gz
	
	# merge the field maps;
	fslmerge -t "$WDIR"/"$i"_AP_PA.nii.gz \
	"$WDIR"/"$i"_AP.nii.gz "$WDIR"/"$i"_PA.nii.gz > /dev/null 2>&1
	
	# prepare field map files using TOPUP; 
	topup --imain="$WDIR"/"$i"_AP_PA.nii.gz --datain="$Subdir"/func/field_maps/acqparams.txt \
	--iout="$WDIR"/"$i"_FM_mag.nii.gz --fout="$WDIR"/"$i"_FM_rads.nii.gz --config=b02b0.cnf > /dev/null 2>&1  
	fslmaths "$WDIR"/"$i"_FM_rads.nii.gz -mul 6.283 "$WDIR"/"$i"_FM_rads.nii.gz # convert to radians 
	fslmaths "$WDIR"/"$i"_FM_mag.nii.gz -Tmean "$WDIR"/"$i"_FM_mag.nii.gz # magnitude image 
	bet "$WDIR"/"$i"_FM_mag.nii.gz "$WDIR"/"$i"_FM_mag_brain.nii.gz -f 0.35 -R # temporary bet image 

	# register reference volume to the T1-weighted anatomical image; use bbr cost function 
	"$RESOURCES"/epi_reg_dof --epi="$WDIR"/"$i"_FM_mag.nii.gz --t1="$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz \
	--t1brain="$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz --out="$WDIR"/"$i"_fm2acpc \
	--wmseg="$Subdir"/anat/T1w/"$Subject"/mri/white.nii.gz --dof=6 > /dev/null 2>&1 

	# use BBRegister to fine-tune the existing co-registration; output FSL style transformation matrix; (not sure why --s isnt working, renaming dir. to "freesurfer" as an ugly workaround)
	bbregister --s freesurfer --mov "$WDIR"/"$i"_fm2acpc.nii.gz --init-reg "$RESOURCES"/eye.dat --surf white.deformed --bold --reg "$WDIR"/"$i"_fm2acpc_bbr.dat --6 --o "$WDIR"/"$i"_fm2acpc_bbr.nii.gz > /dev/null 2>&1  
	tkregister2 --s freesurfer --noedit --reg "$WDIR"/"$i"_fm2acpc_bbr.dat --mov "$WDIR"/"$i"_fm2acpc.nii.gz --targ "$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz --fslregout "$WDIR"/"$i"_fm2acpc_bbr.mat > /dev/null 2>&1  

	# combine original and fine tuned affine matrix;
	convert_xfm -omat "$WDIR"/"$i"_fm2acpc.mat \
	-concat "$WDIR"/"$i"_fm2acpc_bbr.mat \
	"$WDIR"/"$i"_fm2acpc.mat

	# apply transformation to the relevant files;
	flirt -dof 6 -interp spline -in "$WDIR"/"$i"_FM_mag.nii.gz -ref "$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz -out "$WDIR"/FM_mag_acpc_"$i".nii.gz -applyxfm -init "$WDIR"/"$i"_fm2acpc.mat > /dev/null 2>&1  
	flirt -dof 6 -interp spline -in "$WDIR"/"$i"_FM_rads.nii.gz -ref "$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz -out "$WDIR"/FM_rads_acpc_"$i".nii.gz -applyxfm -init "$WDIR"/"$i"_fm2acpc.mat > /dev/null 2>&1  
	wb_command -volume-smoothing "$WDIR"/FM_rads_acpc_"$i".nii.gz 2 "$WDIR"/FM_rads_acpc_"$i"_s2.nii.gz -fix-zeros # apply some gentle regularization; have not tested whether this helps or hurts.

}

# prepare field maps; 
for (( i=0; i<${#ap_fms[@]}; i++ )); do prep_field_maps ; done 

# merge & average the co-registered field map images accross sessions;  
fslmerge -t "$Subdir"/func/field_maps/FM_rads_acpc.nii.gz "$WDIR"/FM_rads_acpc_*_s2.nii.gz > /dev/null 2>&1  
fslmaths "$Subdir"/func/field_maps/FM_rads_acpc.nii.gz -Tmean "$Subdir"/func/field_maps/FM_rads_acpc.nii.gz > /dev/null 2>&1  
fslmerge -t "$Subdir"/func/field_maps/FM_mag_acpc.nii.gz "$WDIR"/FM_mag_acpc_*.nii.gz > /dev/null 2>&1  
fslmaths "$Subdir"/func/field_maps/FM_mag_acpc.nii.gz -Tmean "$Subdir"/func/field_maps/FM_mag_acpc.nii.gz > /dev/null 2>&1  

# perform a final brain extraction;
fslmaths "$Subdir"/func/field_maps/FM_mag_acpc.nii.gz -mas "$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz \
"$Subdir"/func/field_maps/FM_mag_acpc_brain.nii.gz > /dev/null 2>&1  
rm -rf "$Subdir"/anat/T1w/freesurfer/ # remove softlink;



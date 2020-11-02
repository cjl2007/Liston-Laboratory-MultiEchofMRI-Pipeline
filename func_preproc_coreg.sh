#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
T1wTemplate2mm=$4
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases 
SUBJECTS_DIR="$Subdir"/anat/T1w/ # note: this is used for "bbregister" calls;

# define & create a temporary directory;
mkdir -p "$Subdir"/func/rest/AverageSBref
WDIR="$Subdir"/func/rest/AverageSBref

# count the number of sessions
sessions=("$Subdir"/func/unprocessed/rest/session_*)
sessions=$(seq 1 1 "${#sessions[@]}")

# sweep through sessions 
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/unprocessed/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do 

		# define the echo times;
		te=$(cat "$Subdir"/func/rest/session_"$s"/run_"$r"/te.txt)
		n_te=0 # set to zero;

		# use the first echo (w/ least amount of signal dropout) to estimate bias field;
		cp "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/SBref*_E1.nii.gz "$WDIR"/TMP_1.nii.gz
		N4BiasFieldCorrection -d 3 -i "$WDIR"/TMP_1.nii.gz -s 1 -o ["$WDIR"/TMP_restored.nii.gz, \
		"$WDIR"/Bias_field_"$s"_"$r".nii.gz] # estimate field inhomog.; 

		# resample bias field image (ANTs --> FSL orientation);
		flirt -in "$WDIR"/Bias_field_"$s"_"$r".nii.gz -ref "$WDIR"/TMP_1.nii.gz -applyxfm -init "$FSL"/ident.mat -out "$WDIR"/Bias_field_"$s"_"$r".nii.gz -interp spline
		cp "$WDIR"/Bias_field_"$s"_"$r".nii.gz "$Subdir"/func/rest/session_"$s"/run_"$r"/Bias_field.nii.gz

		# sweep the te;
		for i in $te ; do

			# skip the "long" te;
			if [[ $i < 50 ]] ; then 

				n_te=`expr $n_te + 1` # track which te we are on;
				cp "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/SBref*_E"$n_te.nii".gz "$WDIR"/TMP_"$n_te".nii.gz
				fslmaths "$WDIR"/TMP_"$n_te".nii.gz -div "$WDIR"/Bias_field_"$s"_"$r".nii.gz "$WDIR"/TMP_"$n_te".nii.gz # apply correction;

			fi

		done

		# combine & average the te; 
		fslmerge -t "$Subdir"/func/rest/session_"$s"/run_"$r"/SBref.nii.gz "$WDIR"/TMP_*.nii.gz > /dev/null 2>&1  
		fslmaths "$Subdir"/func/rest/session_"$s"/run_"$r"/SBref.nii.gz -Tmean "$Subdir"/func/rest/session_"$s"/run_"$r"/SBref.nii.gz
		cp "$Subdir"/func/rest/session_"$s"/run_"$r"/SBref.nii.gz "$WDIR"/SBref_"$s"_"$r".nii.gz
		rm "$WDIR"/TMP* # remove intermediate files;

	done

done

# build a list of all SBrefs;
images=("$WDIR"/SBref_*.nii.gz)

# count images; average if needed  
if [ "${#images[@]}" \> 1 ]; then

	# align and average the single-band reference images;
	FuncAverage -n -o "$Subdir"/func/xfms/rest/SBref_avg.nii.gz \
	"$WDIR"/SBref_*.nii.gz > /dev/null 2>&1  

else

	# copy over the lone single-band reference image;
	cp "${images[0]}" "$Subdir"/func/xfms/rest/SBref_avg.nii.gz \
	> /dev/null 2>&1 

fi

# create clean tmp. copy of freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1 
cp -rf "$Subdir"/anat/T1w/"$Subject" "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1

# define the effective echo spacing;
echo_spacing=$(cat $Subdir/func/xfms/rest/EffectiveEchoSpacing.txt) 

# register single-band reference image to T1-weighted anatomical image; correct for spatial distortions
"$FSL"/epi_reg_dof --dof=6 --epi="$Subdir"/func/xfms/rest/SBref_avg.nii.gz --t1="$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz --t1brain="$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz --out="$Subdir"/func/xfms/rest/SBref2acpc --fmap="$Subdir"/func/field_maps/FM_rads_acpc.nii.gz --fmapmag="$Subdir"/func/field_maps/FM_mag_acpc.nii.gz \
--fmapmagbrain="$Subdir"/func/field_maps/FM_mag_acpc_brain.nii.gz --echospacing="$echo_spacing" --wmseg="$Subdir"/anat/T1w/"$Subject"/mri/white.nii.gz --nofmapreg --pedir=-y > /dev/null 2>&1 # note: need to manually set --pedir

# use BBRegister to fine-tune the existing co-registration; output FSL style transformation matrix;
bbregister --s freesurfer --mov "$Subdir"/func/xfms/rest/SBref2acpc.nii.gz --init-reg "$FSL"/eye.dat --surf white.deformed --bold --reg "$Subdir"/func/xfms/rest/SBref2acpc_BBR.dat --6 --o "$Subdir"/func/xfms/rest/SBref2acpc_BBR.nii.gz > /dev/null 2>&1  
tkregister2 --s freesurfer --noedit --reg "$Subdir"/func/xfms/rest/SBref2acpc_BBR.dat --mov "$Subdir"/func/xfms/rest/SBref2acpc.nii.gz --targ "$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz --fslregout "$Subdir"/func/xfms/rest/SBref2acpc_BBR.mat > /dev/null 2>&1  

# overwrite previous SBref2acpc file; 
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/SBref_avg.nii.gz --ref="$T1wTemplate2mm" \
--out="$Subdir"/func/xfms/rest/SBref2acpc.nii.gz --warp="$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz

# add bbr step as post warp linear transformation;
convertwarp --warp1="$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz --postmat="$Subdir"/func/xfms/rest/SBref2acpc_BBR.mat \
--ref="$T1wTemplate2mm" --out="$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz

# overwrite previous file (this new one can be used to evaluate whether bbr improves epi_reg co-registeration)
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/SBref_avg.nii.gz --ref="$T1wTemplate2mm" --out="$Subdir"/func/xfms/rest/SBref2acpc_BBR.nii.gz --warp="$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz
invwarp --ref="$Subdir"/func/xfms/rest/SBref_avg.nii.gz -w "$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz -o "$Subdir"/func/xfms/rest/SBref2acpc_inv_warp.nii.gz # invert func --> T1w anatomical warp; includ. dc.;

# combine warps (distorted SBref image --> T1w_acpc & anatomical image in acpc --> MNI atlas)
convertwarp --ref="$T1wTemplate2mm" --warp1="$Subdir"/func/xfms/rest/SBref2acpc_warp.nii.gz --warp2="$Subdir"/anat/MNINonLinear/xfms/acpc_dc2standard.nii.gz --out="$Subdir"/func/xfms/rest/SBref2nonlin_warp.nii.gz
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/SBref_avg.nii.gz --ref="$T1wTemplate2mm" --out="$Subdir"/func/xfms/rest/SBref2nonlin.nii.gz --warp="$Subdir"/func/xfms/rest/SBref2nonlin_warp.nii.gz
invwarp -w "$Subdir"/func/xfms/rest/SBref2nonlin_warp.nii.gz -o "$Subdir"/func/xfms/rest/SBref2nonlin_inv_warp.nii.gz --ref="$Subdir"/func/xfms/rest/SBref_avg.nii.gz # generate an inverse warp; atlas --> distorted SBref image 

# generate a set of functional brain mask (acpc + nonlin) in 2mm atlas space; 
flirt -interp nearestneighbour -in "$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz -ref "$T1wTemplate2mm" -out "$Subdir"/func/xfms/rest/T1w_acpc_brain_2mm.nii.gz -applyxfm -init "$FSL"/ident.mat
fslmaths "$Subdir"/func/xfms/rest/T1w_acpc_brain_2mm.nii.gz -bin "$Subdir"/func/xfms/rest/T1w_acpc_brain_2mm_mask.nii.gz # this is a binarized version of the T1w_acpc_brain.nii.gz image in 2mm atlas space; used for masking functional data
flirt -interp nearestneighbour -in "$Subdir"/anat/MNINonLinear/T1w_restore_brain.nii.gz -ref "$T1wTemplate2mm" -out "$Subdir"/func/xfms/rest/T1w_nonlin_brain_2mm.nii.gz -applyxfm -init "$FSL"/ident.mat # this is the T1w_restore_brain.nii.gz image in 2mm atlas space;
fslmaths "$Subdir"/func/xfms/rest/T1w_nonlin_brain_2mm.nii.gz -bin "$Subdir"/func/xfms/rest/T1w_nonlin_brain_2mm_mask.nii.gz # this is a binarized version of the T1w_nonlin_brain.nii.gz image in 2mm atlas space; used for masking functional data

# remove tmp. freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer/ 












#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

MEDIR=$1
Subject=$2
StudyFolder=$3
Subdir="$StudyFolder"/"$Subject"
SUBJECTS_DIR="$Subdir"/anat/T1w/ # note: this is used for "bbregister" calls;
NTHREADS=$4
StartSession=$5

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# create a temp. "find_fm_params.m"
cp -rf "$MEDIR"/res0urces/find_fm_params.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables
echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
echo StartSession="$StartSession" | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  

# delete some files;
rm "$Subdir"/workspace/temp.m
cd "$Subdir" 

# count the number of sessions
sessions=("$Subdir"/func/unprocessed/rest/session_*)
sessions=$(seq $StartSession 1 "${#sessions[@]}")

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/unprocessed/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# check to see if this file exists or not;
		if [ -f "$Subdir/func/unprocessed/field_maps/AP_S"$s"_R"$r".nii.gz" ]; then

			# the "AllFMs.txt" file contains 
			# dir. paths to every pair of field maps; 
			echo S"$s"_R"$r" >> "$Subdir"/AllFMs.txt  

		fi

	done

done

# define a list of directories;
AllFMs=$(cat "$Subdir"/AllFMs.txt) # note: this is used for parallel processing purposes.
rm "$Subdir"/AllFMs.txt # remove intermediate file;

# create a white matter segmentation (.mgz --> .nii.gz);
mri_binarize --i "$Subdir"/anat/T1w/"$Subject"/mri/aparc+aseg.mgz --wm --o "$Subdir"/anat/T1w/"$Subject"/mri/white.mgz > /dev/null 2>&1  
mri_convert -i "$Subdir"/anat/T1w/"$Subject"/mri/white.mgz -o "$Subdir"/anat/T1w/"$Subject"/mri/white.nii.gz --like "$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz > /dev/null 2>&1   # create a white matter segmentation (.mgz --> .nii.gz);

# create clean tmp. copy of freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1 
cp -rf "$Subdir"/anat/T1w/"$Subject" "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1

# create & define the FM "library"
mkdir -p "$Subdir"/func/field_maps/AllFMs > /dev/null 2>&1
WDIR="$Subdir"/func/field_maps/AllFMs

func () {

	# copy over field map pair to workspace 
	cp "$2"/func/unprocessed/field_maps/AP_"$5".nii.gz "$4"/AP_"$5".nii.gz
	cp "$2"/func/unprocessed/field_maps/PA_"$5".nii.gz "$4"/PA_"$5".nii.gz

	# count the number of volumes;
 	nVols=`fslnvols "$4"/AP_"$5".nii.gz`

 	# avg. the images, if needed
	if [[ $nVols > 1 ]] ; then 
		mcflirt -in "$4"/AP_"$5".nii.gz -out "$4"/AP_"$5".nii.gz
		fslmaths "$4"/AP_"$5".nii.gz -Tmean "$4"/AP_"$5".nii.gz
		mcflirt -in "$4"/PA_"$5".nii.gz -out "$4"/PA_"$5".nii.gz
		fslmaths "$4"/PA_"$5".nii.gz -Tmean "$4"/PA_"$5".nii.gz
	fi

	# merge the field maps into a single 4D image;
	fslmerge -t "$4"/AP_PA_"$5".nii.gz "$4"/AP_"$5".nii.gz "$4"/PA_"$5".nii.gz > /dev/null 2>&1 
	
	# prepare field map files using TOPUP; 
	topup --imain="$4"/AP_PA_"$5".nii.gz --datain="$2"/func/field_maps/acqparams.txt \
	--iout="$4"/FM_mag_"$5".nii.gz --fout="$4"/FM_rads_"$5".nii.gz --config=b02b0.cnf > /dev/null 2>&1  
	fslmaths "$4"/FM_rads_"$5".nii.gz -mul 6.283 "$4"/FM_rads_"$5".nii.gz > /dev/null 2>&1 # convert to radians 
	fslmaths "$4"/FM_mag_"$5".nii.gz -Tmean "$4"/FM_mag_"$5".nii.gz > /dev/null 2>&1 # magnitude image 
	bet "$4"/FM_mag_"$5".nii.gz "$4"/FM_mag_brain_"$5".nii.gz -f 0.35 -R > /dev/null 2>&1 # temporary bet image 

	# register reference volume to the T1-weighted anatomical image; use bbr cost function 
	"$1"/res0urces/epi_reg_dof --epi="$4"/FM_mag_"$5".nii.gz --t1="$2"/anat/T1w/T1w_acpc_dc_restore.nii.gz \
	--t1brain="$2"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz --out="$4"/fm2acpc_"$5" --wmseg="$2"/anat/T1w/"$3"/mri/white.nii.gz --dof=6 > /dev/null 2>&1 

	# use BBRegister to fine-tune the existing co-registration; output FSL style transformation matrix; (not sure why --s isnt working, renaming dir. to "freesurfer" as an ugly workaround)
	bbregister --s freesurfer --mov "$4"/fm2acpc_"$5".nii.gz --init-reg "$1"/res0urces/FSL/eye.dat --surf white.deformed --bold --reg "$4"/fm2acpc_bbr_"$5".dat --6 --o "$4"/fm2acpc_bbr_"$5".nii.gz > /dev/null 2>&1  
	tkregister2 --s freesurfer --noedit --reg "$4"/fm2acpc_bbr_"$5".dat --mov "$4"/fm2acpc_"$5".nii.gz --targ "$2"/anat/T1w/T1w_acpc_dc_restore.nii.gz --fslregout "$4"/fm2acpc_bbr_"$5".mat > /dev/null 2>&1  

	# combine the original and 
	# fine tuned affine matrix;
	convert_xfm -omat "$4"/fm2acpc_"$5".mat \
	-concat "$4"/fm2acpc_bbr_"$5".mat \
	"$4"/fm2acpc_"$5".mat > /dev/null 2>&1

	# apply transformation to the relevant files;
	flirt -dof 6 -interp spline -in "$4"/FM_mag_"$5".nii.gz -ref "$2"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz -out "$4"/FM_mag_acpc_"$5".nii.gz -applyxfm -init "$4"/fm2acpc_"$5".mat > /dev/null 2>&1  
	fslmaths "$4"/FM_mag_acpc_"$5".nii.gz -mas "$2"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz "$4"/FM_mag_acpc_brain_"$5".nii.gz  > /dev/null 2>&1  
	flirt -dof 6 -interp spline -in "$4"/FM_rads_"$5".nii.gz -ref "$2"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz -out "$4"/FM_rads_acpc_"$5".nii.gz -applyxfm -init "$4"/fm2acpc_"$5".mat > /dev/null 2>&1  
	wb_command -volume-smoothing "$4"/FM_rads_acpc_"$5".nii.gz 2 "$4"/FM_rads_acpc_"$5".nii.gz -fix-zeros > /dev/null 2>&1 

}

export -f func # create a field map for all sessions (if possible)
parallel --jobs $NTHREADS func ::: $MEDIR ::: $Subdir ::: $Subject ::: $WDIR ::: $AllFMs > /dev/null 2>&1  

# merge & average the co-registered field map images accross sessions;  
fslmerge -t "$Subdir"/func/field_maps/Avg_FM_rads_acpc.nii.gz "$WDIR"/FM_rads_acpc_S*.nii.gz > /dev/null 2>&1  
fslmaths "$Subdir"/func/field_maps/Avg_FM_rads_acpc.nii.gz -Tmean "$Subdir"/func/field_maps/Avg_FM_rads_acpc.nii.gz > /dev/null 2>&1  
fslmerge -t "$Subdir"/func/field_maps/Avg_FM_mag_acpc.nii.gz "$WDIR"/FM_mag_acpc_S*.nii.gz > /dev/null 2>&1  
fslmaths "$Subdir"/func/field_maps/Avg_FM_mag_acpc.nii.gz -Tmean "$Subdir"/func/field_maps/Avg_FM_mag_acpc.nii.gz > /dev/null 2>&1  

# perform a final brain extraction;
fslmaths "$Subdir"/func/field_maps/Avg_FM_mag_acpc.nii.gz -mas "$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz \
"$Subdir"/func/field_maps/Avg_FM_mag_acpc_brain.nii.gz > /dev/null 2>&1  
rm -rf "$Subdir"/anat/T1w/freesurfer/ # remove softlink;

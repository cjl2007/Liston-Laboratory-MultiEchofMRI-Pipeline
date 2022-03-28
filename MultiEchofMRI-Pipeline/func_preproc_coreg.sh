#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

MEDIR=$1
Subject=$2
StudyFolder=$3
Subdir="$StudyFolder"/"$Subject"
SUBJECTS_DIR="$Subdir"/anat/T1w/ # note: this is used for "bbregister" calls;
AtlasTemplate=$4
DOF=$5
NTHREADS=$6
StartSession=$7

# first, lets read in all the .json files associated with each scan 
# & write out some .txt files that will be used during preprocessing

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1
mkdir "$Subdir"/workspace/ > /dev/null 2>&1

# create temp. find_epi_params.m 
cp -rf "$MEDIR"/res0urces/find_epi_params.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables;
echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
echo FuncName=["'rest'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
echo StartSession="$StartSession" | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1 

# delete some files;
rm -rf "$Subdir"/workspace/
cd "$Subdir" # go back to subject dir. 

# next, we loop through all scans and create SBrefs
# (average of first few echoes) for each scan. This is used (when needed) 
# as an intermediate target for co-registeration.

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
		te=$(cat "$Subdir"/func/rest/session_"$s"/run_"$r"/TE.txt)
		n_te=0 # set to zero;

		# sweep the te;
		for i in $te ; do

			# keep track of 
			# which te we are on;
			n_te=`expr $n_te + 1` 

			# if there is no single-band reference image, we can assume that there 
			# are also a bunch of non-steady state images we need to dump from the start of the time-series...
			if [ ! -f "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/SBref_S"$s"_R"$r"_E"$n_te".nii.gz ]; then
				fslroi "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/Rest_S"$s"_R"$r"_E"$n_te".nii.gz "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/SBref_S"$s"_R"$r"_E"$n_te".nii.gz 10 1 
				echo 10 > "$Subdir"/func/rest/session_"$s"/run_"$r"/rmVols.txt
			fi

		done

		# use the first echo (w/ least amount of signal dropout) to estimate bias field;
		cp "$Subdir"/func/unprocessed/rest/session_"$s"/run_"$r"/SBref*_E1.nii.gz "$WDIR"/TMP_1.nii.gz
		
		# estimate field inhomog. & resample bias field image (ANTs --> FSL orientation);
		N4BiasFieldCorrection -d 3 -i "$WDIR"/TMP_1.nii.gz -o ["$WDIR"/TMP_restored.nii.gz, "$WDIR"/Bias_field_"$s"_"$r".nii.gz] 
		flirt -in "$WDIR"/Bias_field_"$s"_"$r".nii.gz -ref "$WDIR"/TMP_1.nii.gz -applyxfm -init "$MEDIR"/res0urces/ident.mat -out "$WDIR"/Bias_field_"$s"_"$r".nii.gz -interp spline # 

		# set back 
		# to zero;
		n_te=0 

		# sweep the te;
		for i in $te ; do

			# skip the "long" te;
			if [[ $i < 60 ]] ; then 

				n_te=`expr $n_te + 1` # keep track which te we are on;
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

# co-register all SBrefs and create an 
# average SBref for cross-scan allignment 

# build a list of all SBrefs;
images=("$WDIR"/SBref_*.nii.gz)

# count images; average if needed  
if [ "${#images[@]}" \> 1 ]; then

	# align  and average the single-band reference (SBref) images;
	"$MEDIR"/res0urces/FuncAverage -n -o "$Subdir"/func/xfms/rest/AvgSBref.nii.gz \
	"$WDIR"/SBref_*.nii.gz > /dev/null 2>&1 

else

	# copy over the lone single-band reference (SBref) image;
	cp "${images[0]}" "$Subdir"/func/xfms/rest/AvgSBref.nii.gz > /dev/null 2>&1

fi

# create clean tmp. copy of freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1
cp -rf "$Subdir"/anat/T1w/"$Subject" "$Subdir"/anat/T1w/freesurfer > /dev/null 2>&1

# define the effective echo spacing;
EchoSpacing=$(cat $Subdir/func/xfms/rest/EffectiveEchoSpacing.txt) 

# register average SBref image to T1-weighted anatomical image using FSL's EpiReg (correct for spatial distortions using average field map); 
"$MEDIR"/res0urces/epi_reg_dof --dof="$DOF" --epi="$Subdir"/func/xfms/rest/AvgSBref.nii.gz --t1="$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz --t1brain="$Subdir"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz --out="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg --fmap="$Subdir"/func/field_maps/Avg_FM_rads_acpc.nii.gz --fmapmag="$Subdir"/func/field_maps/Avg_FM_mag_acpc.nii.gz --fmapmagbrain="$Subdir"/func/field_maps/Avg_FM_mag_acpc_brain.nii.gz --echospacing="$EchoSpacing" --wmseg="$Subdir"/anat/T1w/"$Subject"/mri/white.nii.gz --nofmapreg --pedir=-y > /dev/null 2>&1 # note: need to manually set --pedir
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/AvgSBref.nii.gz --ref="$AtlasTemplate" --out="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg.nii.gz --warp="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg_warp.nii.gz

# use BBRegister (BBR) to fine-tune the existing co-registration & output FSL style transformation matrix;
bbregister --s freesurfer --mov "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg.nii.gz --init-reg "$MEDIR"/res0urces/eye.dat --surf white.deformed --bold --reg "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.dat --6 --o "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.nii.gz > /dev/null 2>&1 
tkregister2 --s freesurfer --noedit --reg "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.dat --mov "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg.nii.gz --targ "$Subdir"/anat/T1w/T1w_acpc_dc_restore.nii.gz --fslregout "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.mat > /dev/null 2>&1 

# add BBR step as post warp linear transformation & generate inverse warp;
convertwarp --warp1="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg_warp.nii.gz --postmat="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.mat --ref="$AtlasTemplate" --out="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/AvgSBref.nii.gz --ref="$AtlasTemplate" --out="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR.nii.gz --warp="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz
invwarp --ref="$Subdir"/func/xfms/rest/AvgSBref.nii.gz -w "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz -o "$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_inv_warp.nii.gz # invert func --> T1w anatomical warp; includ. dc.;

# combine warps (distorted SBref image --> T1w_acpc & anatomical image in acpc --> MNI atlas)
convertwarp --ref="$AtlasTemplate" --warp1="$Subdir"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz --warp2="$Subdir"/anat/MNINonLinear/xfms/acpc_dc2standard.nii.gz --out="$Subdir"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR_warp.nii.gz
applywarp --interp=spline --in="$Subdir"/func/xfms/rest/AvgSBref.nii.gz --ref="$AtlasTemplate" --out="$Subdir"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR.nii.gz --warp="$Subdir"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR_warp.nii.gz
invwarp -w "$Subdir"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR_warp.nii.gz -o "$Subdir"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR_inv_warp.nii.gz --ref="$Subdir"/func/xfms/rest/AvgSBref.nii.gz # generate an inverse warp; atlas --> distorted SBref image 

# now, lets also co-register individual 
# SBrefs to the target anatomical image;
# note: we will compare which is best 
# (avg. field map vs. scan-specific) later on

# create & define the "CoregQA" folder;
mkdir -p "$Subdir"/func/qa/CoregQA > /dev/null 2>&1

# count the number of sessions
Sessions=("$Subdir"/func/rest/session_*)
Sessions=$(seq $StartSession 1 "${#sessions[@]}")

func () {

	# count number of runs for this session;
	runs=("$2"/func/rest/session_"$6"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# check to see if this scan has a field map or not;
		if [ -f "$2/func/field_maps/AllFMs/FM_rads_acpc_S"$6"_R"$r".nii.gz" ]; then

			# define the effective echo spacing;
			EchoSpacing=$(cat "$2"/func/rest/session_"$6"/run_"$r"/EffectiveEchoSpacing.txt) 
		
			# register average SBref image to T1-weighted anatomical image using FSL's EpiReg (correct for spatial distortions using scan-specific field map); 
			"$1"/res0urces/epi_reg_dof --dof="$4" --epi="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --t1="$2"/anat/T1w/T1w_acpc_dc_restore.nii.gz --t1brain="$2"/anat/T1w/T1w_acpc_dc_restore_brain.nii.gz --out="$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r" --fmap="$2"/func/field_maps/AllFMs/FM_rads_acpc_S"$6"_R"$r".nii.gz --fmapmag="$2"/func/field_maps/AllFMs/FM_mag_acpc_S"$6"_R"$r".nii.gz --fmapmagbrain="$2"/func/field_maps/AllFMs/FM_mag_acpc_brain_S"$6"_R"$r".nii.gz --echospacing="$EchoSpacing" --wmseg="$2"/anat/T1w/"$3"/mri/white.nii.gz --nofmapreg --pedir=-y > /dev/null 2>&1 # note: need to manually set --pedir
			applywarp --interp=spline --in="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --ref="5" --out="$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r".nii.gz --warp="$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r"_warp.nii.gz

			# use BBRegister (BBR) to fine-tune the existing co-registeration; output FSL style transformation matrix;
			bbregister --s freesurfer --mov "$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r".nii.gz --init-reg "$1"/res0urces/eye.dat --surf white.deformed --bold --reg "$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".dat --6 --o "$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".nii.gz > /dev/null 2>&1 
			tkregister2 --s freesurfer --noedit --reg "$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".dat --mov "$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r".nii.gz --targ "$2"/anat/T1w/T1w_acpc_dc_restore.nii.gz --fslregout "$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".mat > /dev/null 2>&1 

			# add BBR step as post warp linear transformation & generate inverse warp;
			convertwarp --warp1="$2"/func/xfms/rest/SBref2acpc_EpiReg_S"$6"_R"$r"_warp.nii.gz --postmat="$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".mat --ref="$5" --out="$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r"_warp.nii.gz
			applywarp --interp=spline --in="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --ref="$5" --out="$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".nii.gz --warp="$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r"_warp.nii.gz
			mv "$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r".nii.gz "$2"/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_ScanSpecificFM_S"$6"_R"$r".nii.gz
			
			# warp SBref image into MNI atlas volume space in a single spline warp; can be used for CoregQA
			convertwarp --ref="$5" --warp1="$2"/func/xfms/rest/SBref2acpc_EpiReg+BBR_S"$6"_R"$r"_warp.nii.gz --warp2="$2"/anat/MNINonLinear/xfms/acpc_dc2standard.nii.gz --out="$2"/func/xfms/rest/SBref2nonlin_EpiReg+BBR_S"$6"_R"$r"_warp.nii.gz
			applywarp --interp=spline --in="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --ref="$5" --out="$2"/func/qa/CoregQA/SBref2nonlin_EpiReg+BBR_ScanSpecificFM_S"$6"_R"$r".nii.gz --warp="$2"/func/xfms/rest/SBref2nonlin_EpiReg+BBR_S"$6"_R"$r"_warp.nii.gz

		fi

        # repeat warps (ACPC, MNI) but this time with the native --> acpc co-registration using an average field map;
        flirt -dof "$4" -in "$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz -ref "$2"/func/xfms/rest/AvgSBref.nii.gz -out "$2"/func/qa/CoregQA/SBref2AvgSBref_S"$6"_R"$r".nii.gz -omat "$2"/func/qa/CoregQA/SBref2AvgSBref_S"$6"_R"$r".mat
        applywarp --interp=spline --in="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --premat="$2"/func/qa/CoregQA/SBref2AvgSBref_S"$6"_R"$r".mat --warp="$2"/func/xfms/rest/AvgSBref2acpc_EpiReg+BBR_warp.nii.gz --out="$2"/func/qa/CoregQA/SBref2acpc_EpiReg+BBR_AvgFM_S"$6"_R"$r".nii.gz --ref="$5"
        applywarp --interp=spline --in="$2"/func/rest/session_"$6"/run_"$r"/SBref.nii.gz --premat="$2"/func/qa/CoregQA/SBref2AvgSBref_S"$6"_R"$r".mat --warp="$2"/func/xfms/rest/AvgSBref2nonlin_EpiReg+BBR_warp.nii.gz --out="$2"/func/qa/CoregQA/SBref2nonlin_EpiReg+BBR_AvgFM_S"$6"_R"$r".nii.gz --ref="$5"

	done
}

export -f func # lets also co-register individual SBrefs to the target anatomical image;
parallel --jobs $NTHREADS func ::: $MEDIR ::: $Subdir ::: $Subject ::: $DOF ::: $AtlasTemplate ::: $Sessions > /dev/null 2>&1  

# finally, lets create files that will be needed later on 
# (brain mask and subcortical mask in functional space)

# generate a set of functional brain mask (acpc + nonlin) in the atlas space; 
flirt -interp nearestneighbour -in "$Subdir"/anat/T1w/T1w_acpc_dc_brain.nii.gz -ref "$AtlasTemplate" -out "$Subdir"/func/xfms/rest/T1w_acpc_brain_func.nii.gz -applyxfm -init "$MEDIR"/res0urces/ident.mat
flirt -interp nearestneighbour -in "$Subdir"/anat/T1w/T1w_acpc_brain_mask.nii.gz -ref "$AtlasTemplate" -out "$Subdir"/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz -applyxfm -init "$MEDIR"/res0urces/ident.mat
flirt -interp nearestneighbour -in "$Subdir"/anat/MNINonLinear/T1w_restore_brain.nii.gz -ref "$AtlasTemplate" -out "$Subdir"/func/xfms/rest/T1w_nonlin_brain_func.nii.gz -applyxfm -init "$MEDIR"/res0urces/ident.mat # this is the T1w_restore_brain.nii.gz image in functional atlas space;
fslmaths "$Subdir"/func/xfms/rest/T1w_nonlin_brain_func.nii.gz -bin "$Subdir"/func/xfms/rest/T1w_nonlin_brain_func_mask.nii.gz # this is a binarized version of the T1w_nonlin_brain.nii.gz image in 2mm atlas space; used for masking functional data

# remove tmp. freesurfer folder;
rm -rf "$Subdir"/anat/T1w/freesurfer/ 

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1
mkdir "$Subdir"/workspace/ > /dev/null 2>&1

# create temp. make_precise_subcortical_labels.m 
cp -rf "$MEDIR"/res0urces/make_precise_subcortical_labels.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables;
echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
echo AtlasTemplate=["'$AtlasTemplate'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
echo SubcorticalLabels=["'$MEDIR/res0urces/FS/SubcorticalLabels.txt'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1 

# delete some files;
rm -rf "$Subdir"/workspace/
cd "$Subdir" # go back to subject dir. 

# finally, evaluate whether scan-specific or average field maps 
# produce the best co-registeration / cross-scan allignment & 
# then generate a movie summarizing the results 

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1
mkdir "$Subdir"/workspace/ > /dev/null 2>&1

# create temporary CoregQA.m 
cp -rf "$MEDIR"/res0urces/coreg_qa.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables;
echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1 		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1

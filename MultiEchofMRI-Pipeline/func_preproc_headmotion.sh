#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

MEDIR=$1
Subject=$2
StudyFolder=$3
Subdir="$StudyFolder"/"$Subject"
AtlasTemplate=$4
DOF=$5
NTHREADS=$6
StartSession=$7

# count the number of sessions
sessions=("$Subdir"/func/rest/session_*)
sessions=$(seq $StartSession 1 "${#sessions[@]}")

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# "AllScans.txt" contains 
		# dir. paths to every scan. 
		echo /session_"$s"/run_"$r" \
		>> "$Subdir"/AllScans.txt  

	done

done

# define a list of directories;
AllScans=$(cat "$Subdir"/AllScans.txt) # note: this is used for parallel processing purposes.
rm "$Subdir"/AllScans.txt # remove intermediate file;

func () {

	# clean up some folders;
	rm -rf "$3"/func/rest/"$5"/MCF > /dev/null 2>&1 # in case there is a previous folder left over;
	mkdir "$3"/func/rest/"$5"/vols/

	# define some acq. parameters;
	te=$(cat "$3"/func/rest/"$5"/TE.txt)
	tr=$(cat "$3"/func/rest/"$5"/TR.txt)
	n_te=0 # set to zero;

	# define some files needed for optimal co-registration & cross-scan allignment
	IntermediateCoregTarget=$(cat "$3"/func/rest/"$5"/IntermediateCoregTarget.txt)
	Intermediate2ACPCWarp=$(cat "$3"/func/rest/"$5"/Intermediate2ACPCWarp.txt)

	# sweep the te;
	for i in $te ; do

		# track which te we are on
		n_te=`expr $n_te + 1` # tick;

		# skip the longer te;
		if [[ $i < 60 ]] ; then 

			# split original 4D resting-state file into single 3D vols.;
			fslsplit "$3"/func/unprocessed/rest/"$5"/Rest*_E"$n_te".nii.gz \
			"$3"/func/rest/"$5"/vols/E"$n_te"_

		fi
	
	done

	# sweep through all of the individual volumes;
	for i in $(seq -f "%04g" 0 $((`fslnvols "$3"/func/unprocessed/rest/"$5"/Rest*_E1.nii.gz` - 1))) ; do

	  	# combine te;
	  	fslmerge -t "$3"/func/rest/"$5"/vols/AVG_"$i".nii.gz "$3"/func/rest/"$5"/vols/E*_"$i".nii.gz   	
		fslmaths "$3"/func/rest/"$5"/vols/AVG_"$i".nii.gz -Tmean "$3"/func/rest/"$5"/vols/AVG_"$i".nii.gz

	done

	# merge the images;
	fslmerge -t "$3"/func/rest/"$5"/Rest_AVG.nii.gz "$3"/func/rest/"$5"/vols/AVG_*.nii.gz # note: used for estimating head motion;
	fslmerge -t "$3"/func/rest/"$5"/Rest_E1.nii.gz "$3"/func/rest/"$5"/vols/E1_*.nii.gz # note: used for estimating (very rough)bias field;
	rm -rf "$3"/func/rest/"$5"/vols/ # remove temporary dir.

	# use the first echo (w/ least amount of signal dropout) to estimate bias field;
	fslmaths "$3"/func/rest/"$5"/Rest_E1.nii.gz -Tmean "$3"/func/rest/"$5"/Mean.nii.gz
	N4BiasFieldCorrection -d 3 -i "$3"/func/rest/"$5"/Mean.nii.gz -o ["$3"/func/rest/"$5"/Mean_Restored.nii.gz,"$3"/func/rest/"$5"/Bias_field.nii.gz] # estimate field inhomog.; 
	rm "$3"/func/rest/"$5"/Rest_E1.nii.gz # remove intermediate file;

	# resample bias field image (ANTs --> FSL orientation);
	flirt -in "$3"/func/rest/"$5"/Bias_field.nii.gz -ref "$3"/func/rest/"$5"/Mean.nii.gz -applyxfm \
	-init "$1"/res0urces/ident.mat -out "$3"/func/rest/"$5"/Bias_field.nii.gz -interp spline

	# remove signal bias; 
	fslmaths "$3"/func/rest/"$5"/Rest_AVG.nii.gz \
	-div "$3"/func/rest/"$5"/Bias_field.nii.gz \
	"$3"/func/rest/"$5"/Rest_AVG.nii.gz

	# remove some intermediate files;
	rm "$3"/func/rest/"$5"/Mean*.nii.gz
	rm "$3"/func/rest/"$5"/Bias*.nii.gz

	# remove the first few volumes if needed;
	if [[ -f "$3"/func/rest/"$5"/rmVols.txt ]]; then
    	nVols=`fslnvols "$3"/func/rest/"$5"/Rest_AVG.nii.gz`
    	rmVols=$(cat "$3"/func/rest/"$5"/rmVols.txt)
		fslroi "$3"/func/rest/"$5"/Rest_AVG.nii.gz "$3"/func/rest/"$5"/Rest_AVG.nii.gz "$rmVols" `expr $nVols - $rmVols`
 	fi

	# run an initial MCFLIRT to get rp. estimates prior to any slice time correction;
	mcflirt -dof "$4" -stages 3 -plots -in "$3"/func/rest/"$5"/Rest_AVG.nii.gz -r "$3"/func/rest/"$5"/SBref.nii.gz -out "$3"/func/rest/"$5"/MCF
	rm "$3"/func/rest/"$5"/MCF.nii.gz # remove .nii output; not used moving forward 

	# perform slice time correction; using custom timing file;
	slicetimer -i "$3"/func/rest/"$5"/Rest_AVG.nii.gz \
	-o "$3"/func/rest/"$5"/Rest_AVG.nii.gz -r $tr \
	--tcustom="$3"/func/rest/"$5"/SliceTiming.txt 

	# now run another MCFLIRT; specify average sbref as ref. vol & output transformation matrices;
	mcflirt -dof "$4" -mats -stages 4 -in "$3"/func/rest/"$5"/Rest_AVG.nii.gz -r "$IntermediateCoregTarget" -out "$3"/func/rest/"$5"/Rest_AVG_mcf 
	rm "$3"/func/rest/"$5"/Rest_AVG*.nii.gz # delete intermediate images; not needed moving forward;

	# sweep all of the echoes; 
	for e in $(seq 1 1 "$n_te") ; do

		# copy over echo "e"; 
		cp "$3"/func/unprocessed/rest/"$5"/Rest*_E"$e".nii.gz \
		"$3"/func/rest/"$5"/Rest_E"$e".nii.gz

		# remove the first few volumes if needed;
		if [[ -f "$3"/func/rest/"$5"/rmVols.txt ]]; then
			fslroi "$3"/func/rest/"$5"/Rest_E"$e".nii.gz "$3"/func/rest/"$5"/Rest_E"$e".nii.gz \
			"$rmVols" `expr $nVols - $rmVols`
	 	fi

		# perform slice time correction using custom timing file;
		slicetimer -i "$3"/func/rest/"$5"/Rest_E"$e".nii.gz \
		--tcustom="$3"/func/rest/"$5"/slice_times.txt \
		-r $tr -o "$3"/func/rest/"$5"/Rest_E"$e".nii.gz

		# split original data into individual volumes;
		fslsplit "$3"/func/rest/"$5"/Rest_E"$e".nii.gz \
		"$3"/func/rest/"$5"/Rest_AVG_mcf.mat/vol_ -t 

		# define affine transformation 
		# matrices and associated target images; 
		mats=("$3"/func/rest/"$5"/Rest_AVG_mcf.mat/MAT_*)
	    images=("$3"/func/rest/"$5"/Rest_AVG_mcf.mat/vol_*.nii.gz)

		# sweep through the split images;
		for (( i=0; i<${#images[@]}; i++ )); do

			# warp image into 2mm MNI atlas space using a single spline transformation; 
			applywarp --interp=spline --in="${images["$i"]}" --premat="${mats["$i"]}" \
			--warp="$Intermediate2ACPCWarp" --out="${images["$i"]}" --ref="$2"
	
		done

		# merge corrected images into a single file & perform a brain extraction
		fslmerge -t "$3"/func/rest/"$5"/Rest_E"$e"_acpc.nii.gz "$3"/func/rest/"$5"/Rest_AVG_mcf.mat/*.nii.gz
		fslmaths "$3"/func/rest/"$5"/Rest_E"$e"_acpc.nii.gz -mas "$3"/func/xfms/rest/T1w_acpc_brain_func_mask.nii.gz \
		"$3"/func/rest/"$5"/Rest_E"$e"_acpc.nii.gz # note: this step reduces file size, which is generally desirable but not absolutely needed.

		# remove some intermediate files;
		rm "$3"/func/rest/"$5"/Rest_AVG_mcf.mat/*.nii.gz # split volumes
		rm "$3"/func/rest/"$5"/Rest_E"$e".nii.gz # raw data 

	done

	# rename mcflirt transform dir.;
	rm -rf "$3"/func/rest/"$5"/MCF > /dev/null 2>&1
	mv "$3"/func/rest/"$5"/*_mcf*.mat "$3"/func/rest/"$5"/MCF

	# use the first echo (w/ least amount of signal dropout) to estimate bias field;
	fslmaths "$3"/func/rest/"$5"/Rest_E1_acpc.nii.gz -Tmean "$3"/func/rest/"$5"/Mean.nii.gz
	fslmaths "$3"/func/rest/"$5"/Mean.nii.gz -thr 0 "$3"/func/rest/"$5"/Mean.nii.gz # remove any negative values introduced by spline interpolation;
	N4BiasFieldCorrection -d 3 -i "$3"/func/rest/"$5"/Mean.nii.gz -o ["$3"/func/rest/"$5"/Mean_Restored.nii.gz,"$3"/func/rest/"$5"/Bias_field.nii.gz] # estimate field inhomog.; 
	flirt -in "$3"/func/rest/"$5"/Bias_field.nii.gz -ref "$3"/func/rest/"$5"/Mean.nii.gz -applyxfm -init "$1"/res0urces/ident.mat -out "$3"/func/rest/"$5"/Bias_field.nii.gz -interp spline # resample bias field image (ANTs --> FSL orientation);

	# sweep all of the echoes; 
	for e in $(seq 1 1 "$n_te") ; do

		# correct for signal inhomog.;
		fslmaths "$3"/func/rest/"$5"/Rest_E"$e"_acpc.nii.gz \
		-div "$3"/func/rest/"$5"/Bias_field.nii.gz \
		"$3"/func/rest/"$5"/Rest_E"$e"_acpc.nii.gz

	done

	# remove some intermediate files;
	rm "$3"/func/rest/"$5"/Mean*.nii.gz

}

export -f func # correct for head motion and warp to atlas space in single spline warp
parallel --jobs $NTHREADS func ::: $MEDIR ::: $AtlasTemplate ::: $Subdir ::: $DOF ::: $AllScans > /dev/null 2>&1  

# finally, calculate frame-wise displacement and generate stop-motion movies 
# summarizing motion and respiration parameters and show minimally preprocessed images;

# # fresh workspace dir.
# rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
# mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# # create & define the "MotionQA" folder;
# rm -rf "$Subdir"/func/qa/MotionQA > /dev/null 2>&1
# mkdir -p "$Subdir"/func/qa/MotionQA > /dev/null 2>&1

# # create a temp. "motion_qa.m"
# cp -rf "$MEDIR"/res0urces/motion_qa.m \
# "$Subdir"/workspace/temp.m

# # define some Matlab variables
# echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
# echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
# cd "$Subdir"/workspace/ # run script via Matlab 
# matlab -nodesktop -nosplash -r "temp; exit" #> /dev/null 2>&1  

# # delete temp. workspace;
# rm -rf "$Subdir"/workspace


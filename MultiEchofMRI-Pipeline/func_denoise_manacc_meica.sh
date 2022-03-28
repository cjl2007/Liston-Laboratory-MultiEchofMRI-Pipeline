#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
MEDIR=$3
NTHREADS=$4
MEPCA=$5
MaxIterations=$6
MaxRestarts=$7
StartSession=$8

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

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

		# remove any existing Tedana+ dirs.;
		rm -rf "$Subdir"/func/rest/session_"$s"/run_"$r"/Tedana+* \
		> /dev/null 2>&1 

		# create temporary parse_man_rej.m 
		cp -rf "$MEDIR"/res0urces/parse_man_rej.m \
		"$Subdir"/workspace/temp.m

		# define some Matlab variables
		echo "addpath(genpath('${MEDIR}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
		echo data_dir=["'$Subdir/func/rest/session_$s/run_$r'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
	
		cd "$Subdir"/workspace/ # run script via Matlab 
		matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  
		rm "$Subdir"/workspace/temp.m # delete some files 
	
		# "data_dirs.txt" contains 
		# dir. paths to every scan. 
		echo /session_"$s"/run_"$r"/ \
		>> "$Subdir"/data_dirs.txt  

	done


done

# define a list of directories;
DataDirs=$(cat "$Subdir"/data_dirs.txt) # note: this is used for parallel processing purposes.
rm "$Subdir"/data_dirs.txt # remove intermediate file;

# delete some files;
rm -rf "$Subdir"/workspace/
cd "$Subdir" # go back to subject dir. 

# activate tedana v10;
source activate me_v10 

func () {

	# make sure that the explicit brain mask and T2* map match; 
	fslmaths "$1"/func/rest/"$6"/Rest_E1_acpc.nii.gz -Tmin "$1"/func/rest/"$6"/tmp.nii.gz # remove any negative values introduced by spline interpolation;
	fslmaths "$1"/func/xfms/rest/T1w_acpc_brain_func.nii.gz -mas "$1"/func/rest/"$6"/tmp.nii.gz "$1"/func/rest/"$6"/brain_mask.nii.gz

	# run the "tedana" workflow; 
	tedana -d "$1"/func/rest/"$6"/Rest_E*_acpc.nii.gz -e $(cat "$1"/func/rest/"$6"/TE.txt) --out-dir "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/ \
	--tedpca "$3" --fittype curvefit --mask "$1"/func/rest/"$6"/brain_mask.nii.gz --t2smap "$1"/func/rest/"$6"/Tedana/t2sv.nii.gz --mix "$1"/func/rest/"$6"/Tedana/ica_mixing.tsv \
	--ctab "$1"/func/rest/"$6"/Tedana/ica_decomposition.json --manacc $(cat "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/AcceptedComponents.txt) \
	--maxit "$4" --maxrestart "$5" --seed 42 # specify more iterations / restarts to increase likelihood of ICA convergence (also increases possible runtime).
	
	# remove temporary files;
	rm "$1"/func/rest/"$6"/brain_mask.nii.gz
	rm "$1"/func/rest/"$6"/tmp.nii.gz

	# move some files;
	mv "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/ts_OC.nii.gz "$1"/func/rest/"$6"/Rest_OCME.nii.gz # overwrite optimally combined time-series;
	mv "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/dn_ts_OC.nii.gz "$1"/func/rest/"$6"/Rest_OCME+MEICA.nii.gz # overwrite multi-echo denoised time-series;

	# sweep through files of interest
	for i in betas_OC t2sv s0v ; do

		# sweep through hemispheres;
		for hemisphere in lh rh ; do

			# set a bunch of different 
			# ways of saying left and right
			if [ $hemisphere = "lh" ] ; then
				Hemisphere="L"
			elif [ $hemisphere = "rh" ] ; then
				Hemisphere="R"
			fi

			# define all of the the relevant surfaces & files;
			PIAL="$1"/anat/T1w/Native/"$2".$Hemisphere.pial.native.surf.gii
			WHITE="$1"/anat/T1w/Native/"$2".$Hemisphere.white.native.surf.gii
			MIDTHICK="$1"/anat/T1w/Native/"$2".$Hemisphere.midthickness.native.surf.gii
			MIDTHICK_FSLR32k="$1"/anat/T1w/fsaverage_LR32k/"$2".$Hemisphere.midthickness.32k_fs_LR.surf.gii
			ROI="$1"/anat/MNINonLinear/Native/"$2".$Hemisphere.roi.native.shape.gii
			ROI_FSLR32k="$1"/anat/MNINonLinear/fsaverage_LR32k/"$2".$Hemisphere.atlasroi.32k_fs_LR.shape.gii
			REG_MSMSulc="$1"/anat/MNINonLinear/Native/"$2".$Hemisphere.sphere.MSMSulc.native.surf.gii
			REG_MSMSulc_FSLR32k="$1"/anat/MNINonLinear/fsaverage_LR32k/"$2".$Hemisphere.sphere.32k_fs_LR.surf.gii

			# map functional data from volume to surface;
			wb_command -volume-to-surface-mapping "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$i".nii.gz "$MIDTHICK" \
			"$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii -ribbon-constrained "$WHITE" "$PIAL"
		
			# dilate metric file 10mm in geodesic space;
			wb_command -metric-dilate "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii \
			"$MIDTHICK" 10 "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii -nearest

			# remove medial wall in native mesh;  
			wb_command -metric-mask "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii \
			"$ROI" "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii 

			# resample metric data from native mesh to fs_LR_32k mesh;
			wb_command -metric-resample "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".native.shape.gii "$REG_MSMSulc" \
			"$REG_MSMSulc_FSLR32k" ADAP_BARY_AREA "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".32k_fs_LR.shape.gii \
			-area-surfs "$MIDTHICK" "$MIDTHICK_FSLR32k" -current-roi "$ROI"

			# remove medial wall in fs_LR_32k mesh;
			wb_command -metric-mask "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".32k_fs_LR.shape.gii \
			"$ROI_FSLR32k" "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$hemisphere".32k_fs_LR.shape.gii

		done

		# map betas to cortical surface (good for manual review of component classification)
		wb_command -cifti-create-dense-timeseries "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$i".dtseries.nii -volume "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/"$i".nii.gz "$1"/func/rois/Subcortical_ROIs_acpc.nii.gz \
		-left-metric "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/lh.32k_fs_LR.shape.gii -roi-left "$1"/anat/MNINonLinear/fsaverage_LR32k/"$2".L.atlasroi.32k_fs_LR.shape.gii \
		-right-metric "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/rh.32k_fs_LR.shape.gii -roi-right "$1"/anat/MNINonLinear/fsaverage_LR32k/"$2".R.atlasroi.32k_fs_LR.shape.gii 
		rm "$1"/func/rest/"$6"/Tedana+ManualComponentClassification/*shape* # remove left over files 

	done

}

export -f func # run tedana;
parallel --jobs $NTHREADS func ::: $Subdir ::: $Subject ::: $MEPCA ::: $MaxIterations ::: $MaxRestarts ::: $DataDirs > /dev/null 2>&1

#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
AtlasSpaceNativeFolder="$Subdir"/anat/T1w/Native
RESOURCES=$3
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases 
NeighborhoodSmoothing="5"
LeftGreyRibbonValue="1"
RightGreyRibbonValue="1"
Factor="0.5"
 
# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace > /dev/null 2>&1 
WDIR="$Subdir"/workspace # define a working dir. 

# count the number of sessions;
sessions=("$Subdir"/func/rest/session_*)
sessions=$(seq 1 1 "${#sessions[@]}")

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# sweep the hemispheres;
		for Hemisphere in L R ; do  
			  wb_command -create-signed-distance-volume "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$Subdir"/func/rest/session_"$s"/run_"$r"/Rest_OCME.nii.gz "$WDIR"/"$Subject"."$Hemisphere".white.native.nii.gz
			  wb_command -create-signed-distance-volume "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$Subdir"/func/rest/session_"$s"/run_"$r"/Rest_OCME.nii.gz "$WDIR"/"$Subject"."$Hemisphere".pial.native.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$WDIR"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$WDIR"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$WDIR"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$WDIR"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$WDIR"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$WDIR"/"$Subject"."$Hemisphere".ribbon.nii.gz
			  fslmaths "$WDIR"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul 1 "$WDIR"/"$Subject"."$Hemisphere".ribbon.nii.gz
			  rm "$WDIR"/"$Subject"."$Hemisphere".white.native.nii.gz "$WDIR"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$WDIR"/"$Subject"."$Hemisphere".pial.native.nii.gz "$WDIR"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
		done

		# cortical ribbon in functional volume space;
		fslmaths "$WDIR"/"$Subject".L.ribbon.nii.gz \
		-add "$WDIR"/"$Subject".R.ribbon.nii.gz "$WDIR"/ribbon_only.nii.gz
		rm "$WDIR"/"$Subject".L.ribbon.nii.gz "$WDIR"/"$Subject".R.ribbon.nii.gz

		# calc. temporal mean, standard deviation, & covariance
		fslmaths "$Subdir"/func/rest/session_"$s"/run_"$r"/Rest_OCME.nii.gz -Tmean "$WDIR"/mean -odt float
		fslmaths "$Subdir"/func/rest/session_"$s"/run_"$r"/Rest_OCME.nii.gz -Tstd "$WDIR"/std -odt float
		fslmaths "$WDIR"/std -div "$WDIR"/mean "$WDIR"/cov
		fslmaths "$WDIR"/cov -mas "$WDIR"/ribbon_only.nii.gz "$WDIR"/cov_ribbon # constrained to ribbon
		fslmaths "$WDIR"/cov_ribbon -div `fslstats "$WDIR"/cov_ribbon -M` "$WDIR"/cov_ribbon_norm
		fslmaths "$WDIR"/cov_ribbon_norm -bin -s "$NeighborhoodSmoothing" "$WDIR"/SmoothNorm
		fslmaths "$WDIR"/cov_ribbon_norm -s "$NeighborhoodSmoothing" -div "$WDIR"/SmoothNorm -dilD "$WDIR"/cov_ribbon_norm_s$NeighborhoodSmoothing
		fslmaths "$WDIR"/cov -div `fslstats "$WDIR"/cov_ribbon -M` -div "$WDIR"/cov_ribbon_norm_s"$NeighborhoodSmoothing" "$WDIR"/cov_norm_modulate
		fslmaths "$WDIR"/cov_norm_modulate -mas "$WDIR"/ribbon_only.nii.gz "$WDIR"/cov_norm_modulate_ribbon

		# define some values;
		STD=`fslstats "$WDIR"/cov_norm_modulate_ribbon -S`
		MEAN=`fslstats "$WDIR"/cov_norm_modulate_ribbon -M`
		Lower=`echo "$MEAN - ($STD * $Factor)" | bc -l`
		Upper=`echo "$MEAN + ($STD * $Factor)" | bc -l`

		# create a "goodvoxels" mask;
		fslmaths "$WDIR"/mean -bin "$WDIR"/mask
		fslmaths "$WDIR"/cov_norm_modulate -thr $Upper -bin -sub "$WDIR"/mask \
		-mul -1 "$WDIR"/GoodVoxels_S"$s"_R"$r".nii.gz

	done

done

# final mask reflects voxels with "good" data in at least one scan;
fslmerge -t "$WDIR"/GoodVoxels.nii.gz "$WDIR"/GoodVoxels_*.nii.gz 
fslmaths "$WDIR"/GoodVoxels.nii.gz -Tmax "$WDIR"/GoodVoxels.nii.gz

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# copy consensus "GoodVoxels" mask to local functional dir.
		cp "$WDIR"/GoodVoxels.nii.gz "$Subdir"/func/rest/session_"$s"/run_"$r"/GoodVoxels.nii.gz

	done

done

rm -rf "$WDIR" # remove temporary workspace;

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# define output dir for CIFTI creation;
		OUT_DIR="$Subdir"/func/rest/session_"$s"/run_"$r"

		# sweep through the files;
		for i in OCME OCME+MEICA ; do

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
				PIAL="$Subdir"/anat/T1w/Native/$Subject.$Hemisphere.pial.native.surf.gii
				WHITE="$Subdir"/anat/T1w/Native/$Subject.$Hemisphere.white.native.surf.gii
				MIDTHICK="$Subdir"/anat/T1w/Native/$Subject.$Hemisphere.midthickness.native.surf.gii
				MIDTHICK_FSLR32k="$Subdir"/anat/T1w/fsaverage_LR32k/$Subject.$Hemisphere.midthickness.32k_fs_LR.surf.gii
				ROI="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.roi.native.shape.gii
				ROI_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.atlasroi.32k_fs_LR.shape.gii
				REG_MSMSulc="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.sphere.MSMSulc.native.surf.gii
				REG_MSMSulc_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.sphere.32k_fs_LR.surf.gii

				# map functional data from volume to surface;
				wb_command -volume-to-surface-mapping "$OUT_DIR"/Rest_"$i".nii.gz "$MIDTHICK" \
				"$OUT_DIR"/"$hemisphere".native.shape.gii -ribbon-constrained "$WHITE" "$PIAL" \
				-volume-roi "$OUT_DIR"/GoodVoxels.nii.gz
			
				# dilate metric file 10mm in geodesic space;
				wb_command -metric-dilate "$OUT_DIR"/"$hemisphere".native.shape.gii \
				"$MIDTHICK" 10 "$OUT_DIR"/"$hemisphere".native.shape.gii -nearest

				# remove medial wall in native mesh;  
				wb_command -metric-mask "$OUT_DIR"/"$hemisphere".native.shape.gii \
				"$ROI" "$OUT_DIR"/"$hemisphere".native.shape.gii 

				# resample metric data from native mesh to fs_LR_32k mesh;
				wb_command -metric-resample "$OUT_DIR"/"$hemisphere".native.shape.gii "$REG_MSMSulc" \
				"$REG_MSMSulc_FSLR32k" ADAP_BARY_AREA "$OUT_DIR"/"$hemisphere".32k_fs_LR.shape.gii \
				-area-surfs "$MIDTHICK" "$MIDTHICK_FSLR32k" -current-roi "$ROI"

				# remove medial wall in fs_LR_32k mesh;
				wb_command -metric-mask "$OUT_DIR"/"$hemisphere".32k_fs_LR.shape.gii \
				"$ROI_FSLR32k" "$OUT_DIR"/"$hemisphere".32k_fs_LR.shape.gii

			done

			# combine hemispheres and subcortical structures into a single CIFTI file;
			tr=$(cat "$Subdir"/func/rest/session_"$s"/run_"$r"/tr.txt) # define the repitition time;
			wb_command -cifti-create-dense-timeseries "$OUT_DIR"/Rest_"$i".dtseries.nii -volume "$Subdir"/func/rest/session_"$s"/run_"$r"/Rest_"$i".nii.gz "$Subdir"/anat/T1w/ROIs/Atlas_ROIs.2.nii.gz \
			-left-metric "$OUT_DIR"/lh.32k_fs_LR.shape.gii -roi-left "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".L.atlasroi.32k_fs_LR.shape.gii \
			-right-metric "$OUT_DIR"/rh.32k_fs_LR.shape.gii -roi-right "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".R.atlasroi.32k_fs_LR.shape.gii -timestep "$tr"
			rm "$OUT_DIR"/*shape* # remove left over files 

		done

	done

done


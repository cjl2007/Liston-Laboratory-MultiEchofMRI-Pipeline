#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases 

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# count the number of sessions
sessions=("$Subdir"/func/rest/session_*)
sessions=$(seq 1 1 "${#sessions[@]}")

# sweep the sessions;
for s in $sessions ; do

	# count number of runs for this session;
	runs=("$Subdir"/func/rest/session_"$s"/run_*)
	runs=$(seq 1 1 "${#runs[@]}")

	# sweep the runs;
	for r in $runs ; do

		# make directory;
		mkdir -p "$out_dir"

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
				PIAL="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.pial.native.surf.gii
				WHITE="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.white.native.surf.gii
				MIDTHICK="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.midthickness.native.surf.gii
				MIDTHICK_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.midthickness.32k_fs_LR.surf.gii
				ROI="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.roi.native.shape.gii
				ROI_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.atlasroi.32k_fs_LR.shape.gii
				REG_MSMSulc="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.sphere.MSMSulc.native.surf.gii
				REG_MSMSulc_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.sphere.32k_fs_LR.surf.gii

				# map functional data from volume to surface;
				wb_command -volume-to-surface-mapping "$Subdir"/func/rest/session_"$s"/run_"$r"/Tedana/Rest_"$i".nii.gz \
				"$MIDTHICK" "$out_dir"/"$hemisphere".native.shape.gii -ribbon-constrained "$WHITE" "$PIAL"
			
				# dilate metric file 10mm in geodesic space;
				wb_command -metric-dilate "$out_dir"/"$hemisphere".native.shape.gii \
				"$MIDTHICK" 10 "$out_dir"/"$hemisphere".native.shape.gii -nearest

				# remove medial wall in native mesh;  
				wb_command -metric-mask "$out_dir"/"$hemisphere".native.shape.gii \
				"$ROI" "$out_dir"/"$hemisphere".native.shape.gii 

				# resample metric data from native mesh to fs_LR_32k mesh;
				wb_command -metric-resample "$out_dir"/"$hemisphere".native.shape.gii "$REG_MSMSulc" \
				"$REG_MSMSulc_FSLR32k" ADAP_BARY_AREA "$out_dir"/"$hemisphere".32k_fs_LR.shape.gii \
				-area-surfs "$MIDTHICK" "$MIDTHICK_FSLR32k" -current-roi "$ROI"

				# remove medial wall in fs_LR_32k mesh;
				wb_command -metric-mask "$out_dir"/"$hemisphere".32k_fs_LR.shape.gii \
				"$ROI_FSLR32k" "$out_dir"/"$hemisphere".32k_fs_LR.shape.gii

			done

			# combine hemispheres and subcortical structures into a single CIFTI file; 
			wb_command -cifti-create-dense-timeseries "$Subdir"/func/rest/session_"$s"/run_"$r"/Ciftis/Rest_"$i".dtseries.nii \
			-volume "$Subdir"/func/rest/session_"$s"/run_"$r"/Tedana/Rest_"$i".nii.gz "$Subdir"/anat/MNINonLinear/ROIs/Atlas_ROIs.2.nii.gz \
			-left-metric "$out_dir"/lh.32k_fs_LR.shape.gii -roi-left "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".L.atlasroi.32k_fs_LR.shape.gii \
			-right-metric "$out_dir"/rh.32k_fs_LR.shape.gii -roi-right "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".R.atlasroi.32k_fs_LR.shape.gii
			rm "$out_dir"/*shape* # remove left over files 

		done

	done

done


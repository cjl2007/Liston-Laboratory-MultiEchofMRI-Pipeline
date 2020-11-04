#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
NTHREADS=$4
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases 
Sigma=`echo "5 / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l` # define sigma for t2* mapping

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# calculate t2* map ;
cp -rf "$RESOURCES"/fit_t2s.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables
echo Subdir=["'$Subdir'"]  | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m
echo resources=["'$RESOURCES'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m
echo ncores="$NTHREADS" | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m 

cd "$Subdir"/workspace/ 
matlab -noFigureWindows -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  
rm "$Subdir"/workspace/temp.m > /dev/null 2>&1  # remove the temp. script
rm "$Subdir"/workspace/* > /dev/null 2>&1  # clean slate

# sweep through hemispheres;
for hemisphere in lh rh ; do

	# define two different 
	# ways of saying left and right;
	if [ $hemisphere = "lh" ] ; then
		Hemisphere="L"
	elif [ $hemisphere = "rh" ] ; then
		Hemisphere="R"
	fi

	# define all of the the relevant surfaces;
	MIDTHICK="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.midthickness.native.surf.gii
	MIDTHICK_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.midthickness.32k_fs_LR.surf.gii
	ROI="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.roi.native.shape.gii
	ROI_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.atlasroi.32k_fs_LR.shape.gii
	REG_MSMSulc="$Subdir"/anat/MNINonLinear/Native/$Subject.$Hemisphere.sphere.MSMSulc.native.surf.gii
	REG_MSMSulc_FSLR32k="$Subdir"/anat/MNINonLinear/fsaverage_LR32k/$Subject.$Hemisphere.sphere.32k_fs_LR.surf.gii

	# create temporary cortical ribbon image in atlas space;
    wb_command -volume-math "(ribbon > ($ribbon - 0.01)) * (ribbon < ($ribbon + 0.01))" "$Subdir"/anat/MNINonLinear/temp_ribbon.nii.gz -var ribbon "$Subdir"/anat/MNINonLinear/ribbon.nii.gz
    flirt -in "$Subdir"/anat/MNINonLinear/temp_ribbon.nii.gz -ref "$Subdir"/func/t2star/T2star_nonlin.nii.gz -out "$Subdir"/anat/MNINonLinear/temp_ribbon.nii.gz -applyxfm -init "$FSL"/ident.mat

	# map t2s map from volume to surface using "myelin" method;
	wb_command -volume-to-surface-mapping "$Subdir"/func/t2star/T2star_nonlin.nii.gz "$MIDTHICK" \
	"$Subdir"/func/t2star/"$hemisphere".native.shape.gii -myelin-style "$Subdir"/anat/MNINonLinear/temp_ribbon.nii.gz \
	"$Subdir"/anat/MNINonLinear/Native/"$Subject"."$Hemisphere".thickness.native.shape.gii "$Sigma"
	rm "$Subdir"/anat/MNINonLinear/temp_ribbon.nii.gz

	# dilate metric file 10mm in geodesic space;
	wb_command -metric-dilate "$Subdir"/func/t2star/"$hemisphere".native.shape.gii \
	"$MIDTHICK" 10 "$Subdir"/func/t2star/"$hemisphere".native.shape.gii -nearest

	# mask out medial wall in native mesh;  
	wb_command -metric-mask "$Subdir"/func/t2star/"$hemisphere".native.shape.gii \
	"$ROI" "$Subdir"/func/t2star/"$hemisphere".native.shape.gii 

	# resample metric data from native mesh to fs_LR_32k mesh;
	wb_command -metric-resample "$Subdir"/func/t2star/"$hemisphere".native.shape.gii "$REG_MSMSulc" \
	"$REG_MSMSulc_FSLR32k" ADAP_BARY_AREA "$Subdir"/func/t2star/"$hemisphere".32k_fs_LR.shape.gii \
	-area-surfs "$MIDTHICK" "$MIDTHICK_FSLR32k" -current-roi "$ROI"

	# mask out medial wall on fs_LR_32k mesh;
	wb_command -metric-mask "$Subdir"/func/t2star/"$hemisphere".32k_fs_LR.shape.gii \
	"$ROI_FSLR32k" "$Subdir"/func/t2star/"$hemisphere".32k_fs_LR.shape.gii

done 

# combine hemispheres and subcortical structures into a single CIFTI files; 
wb_command -cifti-create-dense-timeseries "$Subdir"/func/t2star/T2star.dtseries.nii -volume "$Subdir"/func/t2star/T2star_nonlin.nii.gz "$Subdir"/anat/MNINonLinear/ROIs/Atlas_ROIs.2.nii.gz \
-left-metric "$Subdir"/func/t2star/lh.32k_fs_LR.shape.gii -roi-left "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".L.atlasroi.32k_fs_LR.shape.gii \
-right-metric "$Subdir"/func/t2star/rh.32k_fs_LR.shape.gii -roi-right "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".R.atlasroi.32k_fs_LR.shape.gii
rm "$Subdir"/func/t2star/*shape* # remove left over files 

# smooth with geodesic (for surface data) and Euclidean (for volumetric data) Gaussian kernels; sigma = 2.55
wb_command -cifti-smoothing "$Subdir"/func/t2star/T2star.dtseries.nii 2.55 2.55 COLUMN "$Subdir"/func/t2star/T2star_s2.55.dtseries.nii \
-left-surface "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".L.midthickness.32k_fs_LR.surf.gii -right-surface "$Subdir"/anat/MNINonLinear/fsaverage_LR32k/"$Subject".R.midthickness.32k_fs_LR.surf.gii 
 


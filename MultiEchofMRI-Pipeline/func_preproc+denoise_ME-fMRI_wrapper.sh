#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);

# define the 
# starting point 
if [ -z "$4" ]
	then
	    StartSession=1
	else
	    StartSession=$4
fi

# reformat subject folder path;
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define some directories containing 
# custom matlab scripts and various atlas files;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"

# check to see if there's a symlink to res0urces here
if ! [[ -e ${MEDIR}/res0urces ]]; then
    ln -s ${MEDIR}/../Res0urces ${MEDIR}/res0urces
fi

# these variables should not be changed unless you have a very good reason
DOF=6 # this is the degrees of freedom (DOF) used for SBref --> T1w and EPI --> SBref coregistrations;
CiftiList="$MEDIR"/config/CiftiList.txt # .txt file containing list of files to be mapped to surface. user can specify OCME, OCME+MEICA, OCME+MEICA+MGTR, and/or OCME+MEICA+MGTR_Betas
AtlasTemplate="$MEDIR/res0urces/FSL/MNI152_T1_2mm.nii.gz" # define a lowres MNI template; 
AtlasSpace="T1w" # define either native space ("T1w") or MNI space ("MNINonlinear")
MEPCA=kundu # set the pca decomposition method (see "tedana -h" for more information)
MaxIterations=500 
MaxRestarts=5

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software

echo -e "\nMulti-Echo Preprocessing & Denoising Pipeline" 

echo -e "\nProcessing the Field Maps"

# process all field maps & create an average image 
# for cases where scan-specific maps are unavailable;
"$MEDIR"/func_preproc_fm.sh "$MEDIR" "$Subject" \
"$StudyFolder" "$NTHREADS" "$StartSession"

echo -e "Coregistering SBrefs to the Anatomical Image"

# create an avg. sbref image and co-register that 
# image & all individual SBrefs to the T1w image;
"$MEDIR"/func_preproc_coreg.sh "$MEDIR" "$Subject" "$StudyFolder" \
"$AtlasTemplate" "$DOF" "$NTHREADS" "$StartSession"

echo -e "Correcting for Slice Time Differences, Head Motion, & Spatial Distortion"

# correct func images for slice time differences and head motion;
"$MEDIR"/func_preproc_headmotion.sh "$MEDIR" "$Subject" "$StudyFolder" \
"$AtlasTemplate" "$DOF" "$NTHREADS" "$StartSession"

echo -e "Performing Signal-Decay Based Denoising"

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_meica.sh "$Subject" "$StudyFolder" "$NTHREADS" \
"$MEPCA" "$MaxIterations" "$MaxRestarts" "$StartSession"

echo -e "Removing Spatially Diffuse Noise via MGTR"

# remove spatially diffuse noise; 
"$MEDIR"/func_denoise_mgtr.sh "$Subject" \
"$StudyFolder" "$MEDIR" "$StartSession"

echo -e "Mapping Denoised Functional Data to Surface"

# volume-to-surface + spatial smoothing mapping;
"$MEDIR"/func_vol2surf.sh "$Subject" "$StudyFolder" \
"$MEDIR" "$CiftiList" "$StartSession"




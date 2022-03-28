#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);

# reformat subject folder path;
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define some directories containing 
# custom matlab scripts and various atlas files;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"

# these variables should not be changed unless you have a very good reason
DOF=6 # this is the degrees of freedom (DOF) used for SBref --> T1w and EPI --> SBref coregistrations;
AtlasTemplate="$MEDIR/res0urces/FSL/MNI152_T1_2mm.nii.gz" # define a lowres MNI template; 
AtlasSpace="T1w" # define either native space ("T1w") or MNI space ("MNINonlinear")

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software

echo -e "\nMulti-Echo Preprocessing & Denoising Pipeline" 

echo -e "\nProcessing the Field Maps"

# process all field maps & create an average image 
# for cases where scan-specific maps are unavailable;
"$MEDIR"/func_preproc_fm.sh "$MEDIR" "$Subject" \
"$StudyFolder" "$NTHREADS"
 
echo -e "Coregistering SBrefs to the Anatomical Image"

# create an avg. sbref image and co-register that 
# image & all individual SBrefs to the T1w image;
"$MEDIR"/func_preproc_coreg.sh "$MEDIR" "$Subject" "$StudyFolder" \
"$AtlasTemplate" "$DOF" "$NTHREADS"

echo -e "Correcting for Slice Time Differences, Head Motion, & Spatial Distortion"

# correct func images for slice time differences and head motion;
"$MEDIR"/func_preproc_headmotion.sh "$MEDIR" "$Subject" "$StudyFolder" \
"$AtlasTemplate" "$DOF" "$NTHREADS"
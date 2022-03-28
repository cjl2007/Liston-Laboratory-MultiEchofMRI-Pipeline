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

# these variables should not be changed unless you have a very good reason
DOF=6 # this is the degrees of freedom (DOF) used for SBref --> T1w and EPI --> SBref coregistrations;
CiftiList="$MEDIR"/config/CiftiList.txt # .txt file containing list of files to be mapped to surface. user can specify OCME, OCME+MEICA, OCME+MEICA+MGTR, and/or OCME+MEICA+MGTR_Betas
AtlasTemplate="$MEDIR/res0urces/FSL/MNI152_T1_2mm.nii.gz" # define a lowres MNI template; 
AtlasSpace="T1w" # define either native space ("T1w") or MNI space ("MNINonlinear")
MEPCA=kundu # set the pca decomposition method (see "tedana -h" for more information)
MaxIterations=500 
MaxRestarts=10

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software

echo -e "\nMulti-Echo Preprocessing & Denoising Pipeline" 

echo -e "\nPerforming Signal-Decay Based Denoising (with manual IC classifications)"

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_manacc_meica.sh "$Subject" \
"$StudyFolder" "$MEDIR" "$NTHREADS" "$MEPCA" \
"$MaxIterations" "$MaxRestarts" "$StartSession"

echo -e "Removing Spatially Diffuse Noise via MGTR"

# remove spatially diffuse noise; 
"$MEDIR"/func_denoise_mgtr.sh "$Subject" \
"$StudyFolder" "$MEDIR" "$StartSession"

echo -e "Mapping Denoised Functional Data to Surface"

# volume-to-surface + spatial smoothing mapping;
"$MEDIR"/func_vol2surf.sh "$Subject" "$StudyFolder" \
"$MEDIR" "$CiftiList" "$StartSession"





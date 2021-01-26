#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);

# ME-ICA options;
MEPCA=aic # set the pca decomposition method (see "tedana -h" for more information)
MaxIterations=500 
MaxRestarts=10

# reformat subject folder path  
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define directories;
RESOURCES="/home/charleslynch/res0urces" # this is a folder containing all sorts of stuff needed for this pipeline to work;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"
CiftiList="$MEDIR"/config/CiftiList.txt # .txt file containing list of files to be mapped to surface. user can specify OCME, OCME+MEICA, OCME+MEICA+MGTR, and/or OCME+MEICA+MGTR_Betas
KernelSize="$MEDIR"/config/KernelSize.txt # .txt file containing list of smoothing kernels to be applied to CiftiList

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software
DIR=$(pwd) # note: this is the current dir. (the one from which we will run future sub-functions)
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" # define the Lowres T1w MNI template

echo -e "\nMulti-Echo Denoising Pipeline" 

echo -e "\nPerforming Signal-Decay Based Denoising with Updated Component Classifications "

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_manacc_meica.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS" "$MEPCA" \
"$MaxIterations" "$MaxRestarts"

echo -e "Removing Spatially Diffuse Noise via MGTR"

# remove spatially diffuse noise; 
"$MEDIR"/func_denoise_mgtr.sh "$Subject" \
"$StudyFolder" "$RESOURCES"

echo -e "Mapping Denoised Functional Data to Surface"

# volume-to-surface mapping;
"$MEDIR"/func_vol2surf.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$CiftiList" 

echo -e "Normalizing Time-Series & Applying Spatial Smoothing"

# normalize the time-series & perform spatial smoothing; 
"$MEDIR"/func_smooth.sh "$Subject" "$StudyFolder" \
"$KernelSize" "$CiftiList"



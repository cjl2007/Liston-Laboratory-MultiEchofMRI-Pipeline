#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);
KernelSize=2.55; # note: this is hard set;

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

# define directories
RESOURCES="/home/charleslynch/res0urces" # this is a folder containing all sorts of stuff needed for this pipeline to work;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software
DIR=$(pwd) # note: this is the current dir. (the one from which we will run future sub-functions)
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" # define the Lowres T1w MNI template

echo -e "\nMulti-Echo Denoising Pipeline" 

echo -e "\nCalculating an Average T2* Map"

# calculate the (average) rate of T2* decay at each voxel;
"$MEDIR"/func_denoise_t2star.sh "$Subject" "$StudyFolder" \
"$RESOURCES" "$NTHREADS" "$KernelSize"

echo -e "Performing Signal-Decay Based Denoising"

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_meica.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS" \
"$MEPCA" "$MaxIterations" "$MaxRestarts"
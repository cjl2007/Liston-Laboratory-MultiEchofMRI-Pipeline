#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 #  subject / folder name;
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);

# ME-ICA options;
MEPCA=kundu # set the pca decomposition method (see "tedana -h" for more information)
MaxIterations=500 
MaxRestarts=10

# reformat subject folder path  
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define some directories containing 
# custom matlab scripts and various atlas files;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software

echo -e "\nMulti-Echo Preprocessing & Denoising Pipeline" 

echo -e "\nPerforming Signal-Decay Based Denoising"

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_meica.sh "$Subject" \
"$StudyFolder" "$NTHREADS" "$MEPCA" \
"$MaxIterations" "$MaxRestarts"
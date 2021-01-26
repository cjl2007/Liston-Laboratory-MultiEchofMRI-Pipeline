#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs
NTHREADS=$3 # set number of threads; larger values will reduce runtime (but also increase RAM usage);

# reformat subject folder path  
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define directories
RESOURCES="/home/charleslynch/res0urces" # this is a folder containing all sorts of stuff needed for this pipeline to work;
MEDIR="/home/charleslynch/MultiEchofMRI-Pipeline"
CiftiList="$MEDIR"/config/CiftiList.txt # file containing list of files to be mapped to surface. user can specify OCME, OCME+MEICA, OCME+MEICA+MGTR, and/or OCME+MEICA+MGTR_Betas
KernelSize="$MEDIR"/config/KernelSize.txt # file containing list of smoothing kernels to be applied to CiftiList

# set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software
DIR=$(pwd) # note: this is the current dir. (the one from which we will run future sub-functions)
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" # define the Lowres T1w MNI template

echo -e "\nMulti-Echo Preprocessing & Denoising Pipeline" 

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# create temporary "find_me_params.m"
cp -rf "$RESOURCES"/find_fm_params.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables
echo "addpath(genpath('${RESOURCES}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  

# delete some files;
rm "$Subdir"/workspace/temp.m
cd "$DIR" # go back to original dir.

echo -e "\nConstructing an Average Field Map"

# prepare an avg. field map;
"$MEDIR"/func_preproc_fm.sh "$Subject" \
"$StudyFolder" "$RESOURCES"

# fresh workspace dir.
rm -rf "$Subdir"/workspace/ > /dev/null 2>&1 
mkdir "$Subdir"/workspace/ > /dev/null 2>&1 

# create temporary find_epi_params.m 
cp -rf "$RESOURCES"/find_epi_params.m \
"$Subdir"/workspace/temp.m

# define some Matlab variables;
echo "addpath(genpath('${RESOURCES}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m
echo Subdir=["'$Subdir'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  		
cd "$Subdir"/workspace/ # run script via Matlab 
matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  

# delete some files;
rm -rf "$Subdir"/workspace/
cd "$DIR" # go back to original dir.

echo -e "Coregistering the Average SBref to T1w Image"

# create an avg. sbref image and co-register that image to the T1w image;
"$MEDIR"/func_preproc_coreg.sh "$Subject" "$StudyFolder" "$RESOURCES" "$T1wTemplate2mm" 

echo -e "Correcting for Slice Time Differences and Head Motion"

# correct func images for slice time differences and head motion;
"$MEDIR"/func_preproc_headmotion.sh "$Subject" "$StudyFolder" \
"$RESOURCES" "$T1wTemplate2mm" "$NTHREADS"

echo -e "Calculating an Average T2* Map"

# calculate the (average) rate of T2* decay at each voxel;
"$MEDIR"/func_denoise_t2s.sh "$Subject" "$StudyFolder" \
"$RESOURCES" "$NTHREADS" "$KernelSize"

echo -e "Performing Signal-Decay Based Denoising"

# perform signal-decay denoising; 
"$MEDIR"/func_denoise_meica.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS"

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



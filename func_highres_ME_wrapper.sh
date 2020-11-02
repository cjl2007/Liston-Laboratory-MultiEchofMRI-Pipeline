#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

StudyFolder=$1 # location of Subject folder
Subject=$2 # space delimited list of subject IDs

# reformat subject folder path  
if [ "${StudyFolder: -1}" = "/" ]; then
	StudyFolder=${StudyFolder%?};
fi

# define subject directory;
Subdir="$StudyFolder"/"$Subject"

# define directories
RESOURCES="/home/charleslynch/res0urces"
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases

# set number 
# of threads
NTHREADS=8 

# Set variable value that sets up environment
EnvironmentScript="/home/charleslynch/HCPpipelines-master/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script
source ${EnvironmentScript}	# Set up pipeline environment variables and software
DIR=$(pwd) # note: this is the current dir. (the one from which we will run future sub-functions)

# define some templates;
T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm.nii.gz" # Hires T1w MNI template
T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain.nii.gz" # Hires brain extracted MNI template
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" # Lowres T1w MNI template
T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm.nii.gz" # Hires T2w MNI Template
T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm_brain.nii.gz" # Hires T2w brain extracted MNI Template
T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz" # Lowres T2w MNI Template
TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain_mask.nii.gz" # Hires MNI brain mask template
Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" # Lowres MNI brain mask template

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

# prepare an avg. field map;
./func_preproc_fm.sh "$Subject" \
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

# create an avg. sbref image and 
# co-register that image to the T1w image;
./func_preproc_coreg.sh "$Subject" "$StudyFolder" \
"$RESOURCES" "$T1wTemplate2mm" 

# correct func images for slice
# time differences and head motion;
./func_preproc_headmotion.sh "$Subject" "$StudyFolder" \
"$RESOURCES" "$T1wTemplate2mm" "$NTHREADS"

# calculate the (average) 
# rate of T2* decay at each voxel;
./func_denoise_t2s.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS"

# perform signal-decay denoising; 
./func_denoise_meica.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS"

# volume-to-surface mapping;
./func_vol2surf.sh "$Subject" \
"$StudyFolder" "$RESOURCES" 

# remove spatially diffuse noise; 
./func_denoise_mgtr.sh "$Subject" \
"$StudyFolder" "$RESOURCES" "$NTHREADS"

# normalize time-series & 
# perform spatiall smoothing; 
./func_smooth.sh "$Subject" \
"$StudyFolder" "$RESOURCES"



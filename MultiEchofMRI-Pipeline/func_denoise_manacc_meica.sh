#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
NTHREADS=$4
MEPCA=$5
MaxIterations=$6
MaxRestarts=$7

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

		# remove any existing Tedana+ dirs.;
		rm -rf "$Subdir"/func/rest/session_"$s"/run_"$r"/Tedana+* \
		> /dev/null 2>&1 

		# create temporary parse_man_rej.m 
		cp -rf "$RESOURCES"/parse_man_rej.m \
		"$Subdir"/workspace/temp.m

		# define some Matlab variables
		echo "addpath(genpath('${RESOURCES}'))" | cat - "$Subdir"/workspace/temp.m > temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
		echo data_dir=["'$Subdir/func/rest/session_$s/run_$r'"] | cat - "$Subdir"/workspace/temp.m >> temp && mv temp "$Subdir"/workspace/temp.m > /dev/null 2>&1  
				
		cd "$Subdir"/workspace/ # run script via Matlab 
		matlab -nodesktop -nosplash -r "temp; exit" > /dev/null 2>&1  
		rm "$Subdir"/workspace/temp.m # delete some files 
	
		# "data_dirs.txt" contains 
		# dir. paths to every scan. 
		echo /session_"$s"/run_"$r"/ \
		>> "$Subdir"/data_dirs.txt  

	done


done

# define a list of directories;
data_dirs=$(cat "$Subdir"/data_dirs.txt) # note: this is used for parallel processing purposes.
rm "$Subdir"/data_dirs.txt # remove intermediate file;

# activate tedana v9;
source activate me_v9 

func () {

	# make sure that the explicit brain mask and T2* map match; 
	fslmaths "$1"/func/rest/"$5"/Rest_E1_acpc.nii.gz -Tmin "$1"/func/rest/"$5"/tmp.nii.gz # remove any negative values introduced by spline interpolation;
	fslmaths "$1"/func/xfms/rest/T1w_acpc_brain_2mm.nii.gz -mas "$1"/func/rest/"$5"/tmp.nii.gz "$1"/func/rest/"$5"/brain_mask.nii.gz
	fslmaths "$1"/func/t2star/T2star_acpc.nii.gz -mas "$1"/func/rest/"$5"/tmp.nii.gz "$1"/func/rest/"$5"/T2star_acpc.nii.gz
	fslmaths "$1"/func/rest/"$5"/T2star_acpc.nii.gz -div 1000 "$1"/func/rest/"$5"/T2star_acpc.nii.gz # convert t2s map to seconds; this was a change from tedana v8 --> v9

	# run the "tedana" workflow; 
	tedana -d "$1"/func/rest/"$5"/Rest_E*_acpc.nii.gz -e $(cat "$1"/func/rest/"$5"/te.txt) --out-dir "$1"/func/rest/"$5"/Tedana+ManualComponentClassification/ \
	--tedpca "$2" --fittype curvefit --mask "$1"/func/rest/"$5"/brain_mask.nii.gz --t2smap "$1"/func/rest/"$5"/T2star_acpc.nii.gz --mix "$1"/func/rest/"$5"/Tedana/ica_mixing.tsv \
	--ctab "$1"/func/rest/"$5"/Tedana/ica_decomposition.json --manacc $(cat "$1"/func/rest/"$5"/Tedana+ManualComponentClassification/ManualClassifications.txt) \
	--maxit "$3" --maxrestart "$4" --seed "$RANDOM" # specify more iterations / restarts to increase likelihood of ICA convergence (also increases possible runtime).
	
	# remove temporary files;
	rm "$1"/func/rest/"$5"/brain_mask.nii.gz
	rm "$1"/func/rest/"$5"/T2star_acpc.nii.gz
	rm "$1"/func/rest/"$5"/tmp.nii.gz

	# move some files;
	mv "$1"/func/rest/"$5"/Tedana+ManualComponentClassification/ts_OC.nii.gz "$1"/func/rest/"$5"/Rest_OCME.nii.gz # overwrite optimally combined time-series;
	mv "$1"/func/rest/"$5"/Tedana+ManualComponentClassification/dn_ts_OC.nii.gz "$1"/func/rest/"$5"/Rest_OCME+MEICA.nii.gz # overwrite multi-echo denoised time-series;

}

export -f func # run tedana;
parallel --jobs $NTHREADS func ::: $Subdir ::: $MEPCA ::: $MaxIterations ::: $MaxRestarts ::: $data_dirs > /dev/null 2>&1

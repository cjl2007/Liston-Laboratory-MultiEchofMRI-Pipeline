#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
NTHREADS=$4

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

		# "data_dirs.txt" contains 
		# dir. paths to every scan. 
		echo session_"$s"/run_"$r" \
		>> "$Subdir"/data_dirs.txt  

	done

done

# define a list of directories;
data_dirs=$(cat "$Subdir"/data_dirs.txt) # note: this is used for parallel processing purposes.
rm "$Subdir"/data_dirs.txt # remove intermediate file;

# activate tedana v9;
source activate me_v9 

func () {

	# remove any existing dirs.
	rm -rf "$1"/func/rest/"$2"/Tedana*/ > /dev/null 2>&1 

	# make the explicit brain mask and T2* map match; 
	fslmaths "$1"/func/rest/"$2"/Rest_E1_nonlin.nii.gz -Tmean "$1"/func/rest/"$2"/tmp.nii.gz
	fslmaths "$1"/func/xfms/rest/T1w_nonlin_brain_2mm.nii.gz -mas "$1"/func/rest/"$2"/tmp.nii.gz "$1"/func/rest/"$2"/brain_mask.nii.gz
	fslmaths "$1"/func/t2star/T2star_nonlin.nii.gz -mas "$1"/func/rest/"$2"/tmp.nii.gz "$1"/func/rest/"$2"/T2star_nonlin.nii.gz
	fslmaths "$1"/func/rest/"$2"/T2star_nonlin.nii.gz -div 1000 "$1"/func/rest/"$2"/T2star_nonlin.nii.gz # convert t2s map to seconds; this was a change from tedana v8 --> v9

	# run the "tedana" workflow; 
	tedana -d "$1"/func/rest/"$2"/Rest_E*_nonlin.nii.gz -e $(cat "$1"/func/rest/"$2"/te.txt) --out-dir "$1"/func/rest/"$2"/Tedana/ \
	--tedpca kundu --fittype curvefit --mask "$1"/func/xfms/rest/T1w_nonlin_brain_2mm_mask.nii.gz --t2smap "$1"/func/rest/"$2"/T2star_nonlin.nii.gz \
	--maxit 500 --maxrestart 25 # specify more iterations / restarts to increase likelihood of ICA convergence (also increases possible runtime).
	
	# remove temporary files;
	rm "$1"/func/rest/"$2"/brain_mask.nii.gz
	rm "$1"/func/rest/"$2"/T2star_nonlin.nii.gz
	rm "$1"/func/rest/"$2"/tmp.nii.gz

	# move some files;
	cp "$1"/func/rest/"$2"/Tedana/ts_OC.nii.gz "$1"/func/rest/"$2"/Rest_OCME.nii.gz # optimally combined time-series;
	cp "$1"/func/rest/"$2"/Tedana/dn_ts_OC.nii.gz "$1"/func/rest/"$2"/Rest_OCME+MEICA.nii.gz # multi-echo denoised time-series;

}

export -f func # run tedana;
parallel --jobs $NTHREADS func ::: $Subdir ::: $data_dirs > /dev/null 2>&1 

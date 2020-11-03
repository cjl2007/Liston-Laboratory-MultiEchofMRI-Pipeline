#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

Subject=$1
StudyFolder=$2
Subdir="$StudyFolder"/"$Subject"
RESOURCES=$3
NTHREADS=$4
FS="$RESOURCES/FS" # dir. with FreeSurfer (FS) atlases 
FSL="$RESOURCES/FSL" # dir. with FSL (FSL) atlases 

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
	rm -rf "$2"/func/rest/"$3"/tedana*/ \
	> /dev/null 2>&1 

	# make the explicit brain mask and T2* map match; 
	fslmaths "$2"/func/rest/"$3"/Rest_E1_nonlin.nii.gz -Tmean "$2"/func/rest/"$3"/tmp.nii.gz
	fslmaths "$2"/func/xfms/rest/T1w_nonlin_brain_2mm.nii.gz -mas "$2"/func/rest/"$3"/tmp.nii.gz "$2"/func/rest/"$3"/brain_mask.nii.gz
	fslmaths "$2"/func/t2star/T2star_nonlin.nii.gz -mas "$2"/func/rest/"$3"/tmp.nii.gz "$2"/func/rest/"$3"/T2star_nonlin.nii.gz
	fslmaths "$2"/func/rest/"$3"/T2star_nonlin.nii.gz -div 1000 "$2"/func/rest/"$3"/T2star_nonlin.nii.gz # convert t2s map to seconds; this was a change from tedana v8 --> v9

	# run the "tedana" workflow; 
	tedana -d "$2"/func/rest/"$3"/Rest_E*_nonlin.nii.gz -e $(cat "$2"/func/rest/"$3"/te.txt) --out-dir "$2"/func/rest/"$3"/Tedana/ \
	--tedpca kundu --fittype curvefit --mask "$2"/func/xfms/rest/T1w_nonlin_brain_2mm_mask.nii.gz --t2smap "$2"/func/rest/"$3"/T2star_nonlin.nii.gz \
	--maxit 1000 --maxrestart 15 --lowmem # specify more iterations / restarts to increase likelihood of ICA convergence (also increases possible runtime).
	
	# remove temporary files;
	rm "$2"/func/rest/"$3"/brain_mask.nii.gz
	rm "$2"/func/rest/"$3"/T2star_nonlin.nii.gz
	rm "$2"/func/rest/"$3"/tmp.nii.gz

	# rename some files;
	mv "$2"/func/rest/"$3"/Tedana/ts_OC.nii.gz "$2"/func/rest/"$3"/Tedana/OCME.nii.gz # optimally combined time-series;
	mv "$2"/func/rest/"$3"/Tedana/dn_ts_OC.nii.gz "$2"/func/rest/"$3"/Tedana/OCME+MEICA.nii.gz # multi-echo denoised time-series;

}

export -f func # run tedana;
parallel --jobs $NTHREADS func ::: $FS ::: $Subdir ::: $data_dirs > /dev/null 2>&1 

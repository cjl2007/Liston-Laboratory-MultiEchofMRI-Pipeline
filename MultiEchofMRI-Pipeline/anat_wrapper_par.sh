#!/bin/bash
# CJL; (cjl2007@med.cornell.edu)

# define the subjects;
subjects=$(cat subjects.txt)

functi0n () {

	# run HCP anatomical pipeline;
	./anat_highres_HCP_wrapper_par.sh \
	/home/charleslynch/Storage/storage_3/ME $1

}

export -f functi0n # sweep subjects
parallel --jobs 5 functi0n ::: $subjects


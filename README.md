# Liston-Laboratory-MultiEchofMRI-Pipeline
Repository for "Rapid precision mapping of individuals using multi-echo fMRI" ; Lynch et al. 2020 Cell Reports.

This pipeline was designed to process longitudinal multi-echo fMRI data. It calls scripts developed by the Human Connectome Project (for preprocessing of high resolution anatomical images and the generation of cortical surfaces) and Tedana (for signal-decay based denoising). 

Important Note: Code and instructions for use will be updated on a rolling basis to ensure generalizability of code to other computing environments.

Instructions: Data must be organized in the expected manner (see "ExampleDataOrganization" folder). Some images must also be accompanied by .json files (which can be produced by dicom conversion programs; e.g., "dcm2niix"). The .json files will be used at various points in the functional pipeline to obtain information needed for preprocessing (echo spacing, total readout time, slice time information, etc.) and denoising (echo times, etc.). 

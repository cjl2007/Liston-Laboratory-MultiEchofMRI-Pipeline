# Liston-Laboratory-MultiEchofMRI-Pipeline
Repository for "Rapid precision mapping of individuals using multi-echo fMRI" ; Lynch et al. 2020 Cell Reports

Important Note: This is very much a work in progress. Code and instructions for use will be updated on a rolling basis to ensure generalizability of code to other computing environments and the ability to handle other kinds of multi-echo sequences / sequence parameters.

Data must be organized in the expected manner (see "ExampleDataOrganization" folder). 
Files need to be named in this way / located in these folders. Some images must also be accompanied by .json files (which can be produced by dicom conversion programs; e.g., "dcm2niix"). The .json files will be used at various points in the functional pipeline to obtain information needed for preprocessing (echo spcing, total readout time, slice time information, etc.) and denoising (echo times, etc.).  

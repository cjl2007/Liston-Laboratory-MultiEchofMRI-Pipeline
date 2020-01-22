function [R] = create_reliability_map(C,T,D,E,TR,nbins)
%% cjl2007@med.cornell.edu; CJL 

% Inputs
% "C" : this is a cell array. Each entry corresponds to a different scan. Contains the ".data" field for CIFTI files containing the relevant resting-state time-courses.
% "T" : this is a cell array. Each entry corresponds to a different scan. Contains a temporal mask (a vector of zeros and ones; with zeros representing motion contaminated time points). 
% "D" : this is a matrix ; where entry i,j represents the distance in geodesic (for vertex to vertex) and Euclidean (for voxel to voxel or vertex to voxel) space between points i and j. 
% "E" : this is an array of values indicating the different epochs to test. For example, E = 1:10 would prompt the script to create 10 reliability maps; from 1 minute to 10 minutes; in one minute steps. 
% "TR" : this is the TR used to acquire the data. 
% "nbins" : this is the number of points considered at once. Smaller numbers of bins saves RAM. nbins = ~20 seems to work okay. 

% Outputs
% "R" : is a P x E array; where P = the number of points in the brain and E = the number of epochs tested. The value for point "i" in this array represents how similair the
% functional connectivity of this seed point was across scans; with values approaching 1 indicating better reliabillity.  

% Notes: this can take awhile to run.   

%% 

% create some bins;
bins = round(linspace(1,size(C{1},1),nbins));

% count the 
% number of scans
n_scans = length(C);

% preallocate reliability map;
R = zeros(size(C{1},1),length(E));
   
% sweep the epochs;
for e = 1:length(E)

    % sweep through the bins
    for i = 1:length(bins)-1
        
        % preallocate "corr_map" variable;
        corr_maps = zeros(size(O.data,1),length(bins(i):bins(i+1)),length(sessions));
        
        % sweep the scans;
        for ii = 1:n_scans
            
            % extract and trim the variables;
            ts = C{ii}(:,1:round( (60/TR) * E(e) )) ; % time-series
            tmask = T{ii}(1:round( (60/TR) * E(e) )) ; % temporal mask
            
            % apply motion censoring;
            if sum(tmask) >= round((30/TR)) % this is a work around for the rare instance (usually when e = 1 ) where the epoch is almost completely motion contaminated; skip motion censoring if there is not at least 30 seconds (this is an arbitrary threshold) of clean data.
                ts = ts(:,tmask==1); 
            end
            
            % perform brain-wide correlations;
            corr_maps(:,:,ii) = paircorr_mod(ts(bins(i):bins(i+1),:)',ts')';
        
        end

        % preallocate temporary variable
        temp = zeros(length(bins(i):bins(i+1)),1);
        idx = bins(i):bins(i+1); % set some indices
        
        % sweep through coeffs.
        for ii = 1:length(temp)
            temp(ii) = mean(icatb_mat2vec(corr(squeeze(corr_maps(D(:,idx(ii))>10,ii,:)),'rows','complete'))); 
        end
        
        % assign reliability values;
        R(bins(i):bins(i+1),e) = temp;
        
    end
    
end

end

% cjl; June 21 2019

% this is a function from the GIFT ICA fMRI toolbox; used here to convert matrix into a vector 
function [vec, IND] = icatb_mat2vec(mat)
% [vec, IND] = mat2vec(mat)
% Returns the lower triangle of mat
% mat should be square [m x m], or if 3-dims should be [n x m x m]

if ndims(mat) == 2
    
    [n,m] = size(mat);
    if n ~=m
        error('mat must be square!')
    end
elseif ndims(mat) == 3
    
    [n,m,m2] = size(mat);
    if m ~= m2
        error('2nd and 3rd dimensions must be equal!')
    end
end

temp = ones(m);
%% find the indices of the lower triangle of the matrix
IND = find((temp-triu(temp))>0);
if ndims(mat) == 2
    vec = mat(IND);
else
    mat = reshape(mat, n, m*m2);
    vec = mat(:,IND);
end
end

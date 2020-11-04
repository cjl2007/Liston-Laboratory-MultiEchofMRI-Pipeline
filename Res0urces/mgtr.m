% CJL; cjl2007@med.cornell.edu 

% turn off
% warnings
warning off;

% load denoised cifti; 
C = ft_read_cifti_mod(input); 
O = C; % preallocate output variable

% count the number of cortical vertices;
ncortverts = nnz(C.brainstructure==1) + nnz(C.brainstructure==2);

% calculate mean gray 
% matter time-series;
mgts = mean(C.data(1:ncortverts,:));

% sweep vertices;
for i = 1:size(C.data,1)
    
    % remove the mean gray matter signal;
    [~,~,O.data(i,:),~,~] = regress(C.data(i,:)',[mgts' ones(length(mgts),1)]);
    
end

% write out results; 
ft_write_cifti_mod(output,O);
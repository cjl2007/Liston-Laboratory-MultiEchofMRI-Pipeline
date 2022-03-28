% read in all components manually identifed as noise;
tmp = dir([data_dir '/Tedana/figures/ManuallyRejected/*.png']);
man_rej = []; % preallocate

% sweep the components;
for i = 1:length(tmp)
    
    % component number;
    str = tmp(i).name;
    str = strsplit(str,{'_','.'});
    str = str{2};
    str = strip(str,'left','0');
    
    % this shouldnt happen, 
    % but just in case...
    if isempty(str)
        str = '0';
    end
    
    % log manually rejected component;
    man_rej = [ man_rej str2double(str) ];
    
end

% read in all components manually identifed as signal;
tmp = dir([data_dir '/Tedana/figures/ManuallyAccepted/*.png']);
man_acc = []; % preallocate

% sweep the components;
for i = 1:length(tmp)
    
    % component number;
    str = tmp(i).name;
    str = strsplit(str,{'_','.'});
    str = str{2};
    str = strip(str,'left','0');
    
    % this shouldnt happen,
    % but just in case...
    if isempty(str)
        str = '0';
    end
    
    % log manually rejected component;
    man_acc = [ man_acc str2double(str) ];
    
end

% load .json file;
json = loadjson([data_dir '/Tedana/ica_decomposition.json']);
fn = fieldnames(json);

% first field "Method"
% is not of interest;
idx = strfind(fn,'ica');
idx = find(not(cellfun('isempty',idx))); % so, ignore it. 

% sweep all of
% the components; 
for i = 1:length(idx)
    
    % log manual component classifications;
    if ~ismember((i - 1),man_rej) && ~strcmp(json.(fn{idx(i)}).classification,'rejected')
        man_acc = [man_acc i-1]; % note: first component is 0; so i = 1 is i -1
    end
    
end

% sort components;
man_acc = sort(man_acc);

% make second tedana directory;
system(['mkdir ' data_dir '/Tedana+ManualComponentClassification']);

% preallocate;
AcceptedComponents = [];

% sweep the components ;
for i = 1:length(man_acc)
    AcceptedComponents = [AcceptedComponents ' ' num2str(man_acc(i))];
end

% write out the lists;
system(['echo -ne ' AcceptedComponents ' >> ' data_dir '/Tedana+ManualComponentClassification/AcceptedComponents.txt']);

try
    
% read in components mapped to cortical surface;
C = ft_read_cifti_mod([data_dir '/Tedana/betas_OC.dtseries.nii']);

Ca = C; % these are the accepted components;
Ca.data = C.data(:,man_acc+1); 

% write out the Ciftis;
ft_write_cifti_mod([data_dir '/Tedana+ManualComponentClassification/betas_OC.dtseries.nii'],C);
ft_write_cifti_mod([data_dir '/Tedana+ManualComponentClassification/betas_OC_Accepted.dtseries.nii'],Ca);

C.data(:,man_acc+1) = []; % now, the rejected components;
ft_write_cifti_mod([data_dir '/Tedana+ManualComponentClassification/betas_OC_Rejected.dtseries.nii'],C);

catch
end




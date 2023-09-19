
% load the template network FC maps;
TemplateFC = ft_read_cifti_mod('TemplateNetworkFC.dtseries.nii');

% load .json file;
json = loadjson([data_dir '/Tedana/ica_decomposition.json']);
fn = fieldnames(json);
idx = strfind(fn,'ica');
idx = find(not(cellfun('isempty',idx))); % so, ignore it.

% preallocate;
acc = [];

% sweep all of
% the components;
for ii = 1:length(idx)
    % log manual component classifications;
    if ~strcmp(json.(fn{idx(ii)}).classification,'rejected')
        acc = [acc ii-1]; % note: first component is 0; so i = 1 is i -1
    end
end

% generate a list of all the images;
images = dir([data_dir '/Tedana/figures/*.png']);
            
% these are the ICs maps;
IC = ft_read_cifti_mod([data_dir '/Tedana/betas_OC.dtseries.nii']);

% calculate spatial similarity
% between the  "noise" ICs and template networks;
rho = corr(IC.data(1:59412,acc+1),TemplateFC.data(1:59412,:));

% manually reject any components with r < 0.05
% spatial correlation with network templates;
ManRej = acc(max(abs(rho),[],2) < 0.05);

% sweep the manually
% accepted components;
for ii  = 1:length(ManRej) 
    system(['cp ' data_dir '/Tedana/figures/' images(ManRej(ii)+1).name ' ' data_dir '/Tedana/figures/ManuallyRejected/']);  
end

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




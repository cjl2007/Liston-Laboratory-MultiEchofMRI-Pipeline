
% set the number 
% of threads
nslots = ncores;

% start parpool;
pool = parpool('local',nslots);

% obtain random seed 
rn = ceil(rand * 1000);

try % make hidden directory
    mkdir(['.tmp'  num2str(rn) '/']);
catch
end

% load
% reference CIFTI
if ischar(ref_cifti)
    ref_cifti = ft_read_cifti_mod(ref_cifti);
end

ref_cifti.data=[]; % remove data, not needed

% load midthickness surfaces 
LH = gifti(mid_surfs{1});
RH = gifti(mid_surfs{2});

% find cortical vertices on surface cortex (not medial wall)
lh_idx = ref_cifti.brainstructure(1:length(LH.vertices))~=-1;
rh_idx = ref_cifti.brainstructure((length(LH.vertices)+1):(length(LH.vertices)+length(RH.vertices)))~=-1;

% preallocate "reference verts"
LH_verts=1:length(LH.vertices);
RH_verts=1:length(RH.vertices);

% cortical vertices only
LH_verts=LH_verts(lh_idx);
RH_verts=RH_verts(rh_idx);

% sweep through vertices
parfor i = 1:length(LH_verts)
    
    % calculate geodesic distances from vertex i
    system(['wb_command -surface-geodesic-distance ' mid_surfs{1} ' ' num2str(LH_verts(i)-1) ' .tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    tmp = gifti(['.tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    system(['rm .tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    lh(:,i) = tmp.cdata(lh_idx); % log distances
        
end

% convert to uint8
lh = uint8(lh);

% sweep through vertices
parfor i = 1:length(RH_verts)
    
    % calculate geodesic distances from vertex i
    system(['wb_command -surface-geodesic-distance ' mid_surfs{2} ' ' num2str(RH_verts(i)-1) ' .tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    tmp = gifti(['.tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    system(['rm .tmp' num2str(rn) '/tmp_' num2str(i) '.shape.gii']);
    rh(:,i) = tmp.cdata(rh_idx); % log distances
    
end

% delete 
% parpool
delete(pool);

% remove tmp dir
[~,~]=system(['rm -rf .tmp'...
    num2str(rn) '/']);

% convert to uint8
rh = uint8(rh);

% piece together results (999 = inter-hemispheric)
top = [lh ones(length(lh),length(rh))*999]; % lh & dummy rh
bottom = [ones(length(rh),length(lh))*999 rh]; % dummy lh & rh
D = uint8([top;bottom]); % combine hemispheres; cortical surface only so far 

% extract coordinates for all cortical vertices 
coords_surf=[LH.vertices; RH.vertices]; % combine hemipsheres 
surf_indices_incifti = ref_cifti.brainstructure > 0 & ref_cifti.brainstructure < 3;
surf_indices_incifti = surf_indices_incifti(1:size(coords_surf,1));
coords_surf = coords_surf(surf_indices_incifti,:);
coords_subcort = ref_cifti.pos(ref_cifti.brainstructure>2,:);
coords = [coords_surf;coords_subcort]; % combine 

% compute euclidean distance 
% between all vertices & voxels 
D2 = uint8(pdist2(coords,coords));

% combine distance matrices; geodesic & euclidean  
D = [D ; D2(size(D,1)+1:end,1:size(D,2))]; % vertcat
D = [D  D2(1:size(D,1),size(D,2)+1:end)]; % horzcat 
clear D2;

% save distance matrix (vertices)
save([out_dir '/distances'],'D','-v7.3');

% clear 
% distances
clear D;


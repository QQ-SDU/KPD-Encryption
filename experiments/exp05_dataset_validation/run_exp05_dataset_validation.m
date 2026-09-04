function [individual, aggregate] = run_exp05_dataset_validation(K, num_rounds, runtime_repeats)
%RUN_EXP05_DATASET_VALIDATION Exp05: dataset-level validation on USC-SIPI + Kodak.
%
% Purpose
% -------
% Validate the representative operating point selected by Exp01/Exp02:
%   K = 100 ordered CLSA-KPD groups
%   R = 3 encryption rounds
%
% Datasets
% --------
% 1) USC-SIPI: all currently available 256x256 images in
%       data/USC_SIPI/gray_256
%       data/USC_SIPI/color_256
%    (6 grayscale + 7 RGB in the current project)
%
% 2) Kodak Lossless True Color Image Suite: 24 RGB images.
%    The script automatically downloads the original PNGs (if missing) and
%    takes a CENTER 256x256 CROP WITHOUT RESIZING.

project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root);
setup_paths();
cfg = default_config(project_root);

if nargin < 1 || isempty(K), K = 100; end
if nargin < 2 || isempty(num_rounds), num_rounds = 3; end
if nargin < 3 || isempty(runtime_repeats), runtime_repeats = 3; end
validateattributes(K, {'numeric'}, {'scalar','integer','positive'});
validateattributes(num_rounds, {'numeric'}, {'scalar','integer','positive'});
validateattributes(runtime_repeats, {'numeric'}, {'scalar','integer','positive'});

fprintf('=== exp05 dataset-level validation ===\n');
fprintf('Representative operating point: K=%d, R=%d\n', K, num_rounds);
fprintf('Runtime repeats per image: %d\n\n', runtime_repeats);

kodak_root = fullfile(project_root, 'data', 'Kodak_256');
kodak_manifest = prepare_kodak_256(project_root, kodak_root);
records = build_dataset_records(project_root, kodak_manifest);
fprintf('Dataset records: %d images\n', height(records));
fprintf('  USC-SIPI : %d\n', sum(records.Dataset == "USC-SIPI"));
fprintf('  Kodak    : %d\n\n', sum(records.Dataset == "Kodak"));

n = cfg.representation.partition_256;
if prod(n) ~= 256*256, error('exp05:Partition', 'partition_256 must multiply to 256*256.'); end
params_per_group = sum(n);
parameter_rate_pct = params_per_group * K / (256*256) * 100;
enc_cfg = cfg.encryption; enc_cfg.num_rounds = num_rounds;
dummy_param = zeros(params_per_group,1);
[dummy_block, ~] = serialize_group(dummy_param);
block_bytes = numel(dummy_block);
[npcr_critical, uaci_low, uaci_high] = random_cipher_thresholds(block_bytes, 0.05);

N = height(records);
Image = strings(N,1); Dataset = strings(N,1); ImageType = strings(N,1);
Channels = zeros(N,1); KUsed = zeros(N,1); ParameterRatePct = repmat(parameter_rate_pct,N,1);
PSNR_KPD = zeros(N,1); SSIM_KPD = zeros(N,1); EntropyPooled = zeros(N,1);
NPCRMean = zeros(N,1); NPCRStd = zeros(N,1); NPCRMin = zeros(N,1); NPCRMax = zeros(N,1);
UACIMean = zeros(N,1); UACIStd = zeros(N,1); UACIMin = zeros(N,1); UACIMax = zeros(N,1);
NPCRPassPct = zeros(N,1); UACIPassPct = zeros(N,1); JointPassPct = zeros(N,1);
EncTotalMean_ms = zeros(N,1); EncTotalStd_ms = zeros(N,1); DecTotalMean_ms = zeros(N,1); DecTotalStd_ms = zeros(N,1);
EncPerGroupMean_ms = zeros(N,1); DecPerGroupMean_ms = zeros(N,1);
AllParametersBitExact = false(N,1); ReconstructionEquivalent = false(N,1);
CacheCreated = false(N,1); RepresentationCache = strings(N,1); group_tables = cell(N,1);

for idx = 1:N
    file_path = char(records.FilePath(idx));
    [I, meta] = load_image_record(file_path);
    if meta.height ~= 256 || meta.width ~= 256
        error('exp05:ImageSize','Exp05 expects 256x256 input. Got %dx%d: %s',meta.height,meta.width,meta.filename);
    end
    Image(idx)=string(meta.filename); Dataset(idx)=records.Dataset(idx); Channels(idx)=meta.channels;
    if meta.channels==1, ImageType(idx)="gray"; else, ImageType(idx)="color"; end

    [rep, cache_file, cache_created] = get_or_create_representation_cache(I, meta, n, K, cfg);
    CacheCreated(idx)=cache_created; RepresentationCache(idx)=string(cache_file);
    K_available=min(cellfun(@(c)c.K,rep.channel)); K_use=min(K,K_available); KUsed(idx)=K_use;

    I_kpd=reconstruct_representation(rep,K_use); I_kpd_u8=clip_image_uint8(I_kpd); I_ref=uint8(I);
    PSNR_KPD(idx)=image_psnr(I_ref,I_kpd_u8); SSIM_KPD(idx)=image_ssim(I_ref,I_kpd_u8);

    total_groups=K_use*meta.channels;
    param_groups=cell(meta.channels,K_use); keys=cell(meta.channels,K_use); cipher_groups=cell(meta.channels,K_use);
    rng(cfg.seed+500000+idx*10000,'twister');
    for ch=1:meta.channels
        for k=1:K_use
            param_groups{ch,k}=concat_factors(rep.channel{ch}.groups{k});
            keys{ch,k}=make_group_key(num_rounds,cfg.encryption.a_max);
        end
    end

    cipher_pool=zeros(total_groups*block_bytes,1,'uint8'); npcr_vals=zeros(total_groups,1); uaci_vals=zeros(total_groups,1);
    channel_id=zeros(total_groups,1); group_id=zeros(total_groups,1); exact_all=true; ptr_pool=1; g=0; decrypted_rep=rep;
    for ch=1:meta.channels
        for k=1:K_use
            g=g+1; param_vec=param_groups{ch,k}; key=keys{ch,k};
            [cipher,~]=encrypt_group(param_vec,enc_cfg,key); cipher_groups{ch,k}=cipher;
            recovered=decrypt_group(cipher,key,enc_cfg); exact=isequal(recovered,param_vec); exact_all=exact_all&&exact;
            if ~exact, error('exp05:DecryptMismatch','Bit-exact recovery failed: image=%s, channel=%d, group=%d.',meta.filename,ch,k); end
            decrypted_rep.channel{ch}.groups{k}=split_factors(recovered,n);
            cb=uint8(cipher.bytes); cipher_pool(ptr_pool:ptr_pool+numel(cb)-1)=cb(:); ptr_pool=ptr_pool+numel(cb);
            [plain_block,serialization]=serialize_group(param_vec); perturbed_block=plain_block; perturbed_block(1)=bitxor(perturbed_block(1),uint8(1));
            perturbed_param=deserialize_group(perturbed_block,serialization);
            [cipher_perturbed,~]=encrypt_group(perturbed_param,enc_cfg,key);
            [npcr_vals(g),uaci_vals(g)]=npcr_uaci(cipher.bytes,cipher_perturbed.bytes);
            channel_id(g)=ch; group_id(g)=k;
        end
    end
    AllParametersBitExact(idx)=exact_all;
    I_dec=reconstruct_representation(decrypted_rep,K_use); ReconstructionEquivalent(idx)=isequal(I_dec,I_kpd);
    if ~ReconstructionEquivalent(idx), error('exp05:ReconstructionMismatch','Decrypted reconstruction differs from direct KPD reconstruction: %s',meta.filename); end

    EntropyPooled(idx)=entropy_uint8(cipher_pool);
    NPCRMean(idx)=mean(npcr_vals); NPCRStd(idx)=std(npcr_vals,0); NPCRMin(idx)=min(npcr_vals); NPCRMax(idx)=max(npcr_vals);
    UACIMean(idx)=mean(uaci_vals); UACIStd(idx)=std(uaci_vals,0); UACIMin(idx)=min(uaci_vals); UACIMax(idx)=max(uaci_vals);
    npcr_pass=npcr_vals>npcr_critical; uaci_pass=uaci_vals>uaci_low & uaci_vals<uaci_high;
    NPCRPassPct(idx)=mean(npcr_pass)*100; UACIPassPct(idx)=mean(uaci_pass)*100; JointPassPct(idx)=mean(npcr_pass&uaci_pass)*100;
    group_tables{idx}=table(repmat(Dataset(idx),total_groups,1),repmat(Image(idx),total_groups,1),channel_id,group_id,npcr_vals,uaci_vals,npcr_pass,uaci_pass,'VariableNames',{'Dataset','Image','Channel','Group','NPCR','UACI','NPCRPass','UACIPass'});

    [warm_cipher,~]=encrypt_group(param_groups{1,1},enc_cfg,keys{1,1}); %#ok<NASGU>
    warm_rec=decrypt_group(warm_cipher,keys{1,1},enc_cfg); %#ok<NASGU>
    enc_times=zeros(runtime_repeats,1); dec_times=zeros(runtime_repeats,1);
    for t=1:runtime_repeats
        tic; for ch=1:meta.channels, for k=1:K_use, encrypt_group(param_groups{ch,k},enc_cfg,keys{ch,k}); end, end; enc_times(t)=toc;
        tic; for ch=1:meta.channels, for k=1:K_use, decrypt_group(cipher_groups{ch,k},keys{ch,k},enc_cfg); end, end; dec_times(t)=toc;
    end
    EncTotalMean_ms(idx)=1000*mean(enc_times); EncTotalStd_ms(idx)=1000*std(enc_times,0);
    DecTotalMean_ms(idx)=1000*mean(dec_times); DecTotalStd_ms(idx)=1000*std(dec_times,0);
    EncPerGroupMean_ms(idx)=EncTotalMean_ms(idx)/total_groups; DecPerGroupMean_ms(idx)=DecTotalMean_ms(idx)/total_groups;
end

individual=table(Dataset,Image,ImageType,Channels,KUsed,ParameterRatePct,PSNR_KPD,SSIM_KPD,EntropyPooled,NPCRMean,NPCRStd,NPCRMin,NPCRMax,UACIMean,UACIStd,UACIMin,UACIMax,NPCRPassPct,UACIPassPct,JointPassPct,EncTotalMean_ms,EncTotalStd_ms,DecTotalMean_ms,DecTotalStd_ms,EncPerGroupMean_ms,DecPerGroupMean_ms,AllParametersBitExact,ReconstructionEquivalent,CacheCreated,RepresentationCache);
agg_usc=aggregate_rows(individual,individual.Dataset=="USC-SIPI","USC-SIPI");
agg_kodak=aggregate_rows(individual,individual.Dataset=="Kodak","Kodak");
agg_all=aggregate_rows(individual,true(height(individual),1),"Overall"); aggregate=[agg_usc;agg_kodak;agg_all];

if exist(cfg.results.tables,'dir')~=7, mkdir(cfg.results.tables); end
individual_file=fullfile(cfg.results.tables,'exp05_dataset_individual.csv'); aggregate_file=fullfile(cfg.results.tables,'exp05_dataset_aggregate.csv');
writetable(individual,individual_file); writetable(aggregate,aggregate_file);
group_metrics=vertcat(group_tables{:}); group_file=fullfile(cfg.results.tables,'exp05_dataset_group_metrics.csv'); writetable(group_metrics,group_file);
raw_dir=fullfile(cfg.results.raw,'exp05_dataset'); if exist(raw_dir,'dir')~=7, mkdir(raw_dir); end
artifact_file=fullfile(raw_dir,'exp05_dataset_validation.mat');
save(artifact_file,'individual','aggregate','group_metrics','records','K','num_rounds','runtime_repeats','n','parameter_rate_pct','npcr_critical','uaci_low','uaci_high','cfg','-v7.3');

disp(aggregate);
end

function records=build_dataset_records(project_root,kodak_manifest)
usc_gray_dir=fullfile(project_root,'data','USC_SIPI','gray_256'); usc_color_dir=fullfile(project_root,'data','USC_SIPI','color_256');
gray_files=dir(fullfile(usc_gray_dir,'*.tiff')); color_files=dir(fullfile(usc_color_dir,'*.tiff'));
Dataset=strings(0,1); FilePath=strings(0,1);
for i=1:numel(gray_files), Dataset(end+1,1)="USC-SIPI"; FilePath(end+1,1)=string(fullfile(gray_files(i).folder,gray_files(i).name)); end %#ok<AGROW>
for i=1:numel(color_files), Dataset(end+1,1)="USC-SIPI"; FilePath(end+1,1)=string(fullfile(color_files(i).folder,color_files(i).name)); end %#ok<AGROW>
for i=1:height(kodak_manifest), Dataset(end+1,1)="Kodak"; FilePath(end+1,1)=kodak_manifest.CropFile(i); end %#ok<AGROW>
records=sortrows(table(Dataset,FilePath),{'Dataset','FilePath'});
end

function manifest=prepare_kodak_256(project_root,crop_dir)
original_dir=fullfile(project_root,'data','Kodak_original'); if exist(original_dir,'dir')~=7, mkdir(original_dir); end
if exist(crop_dir,'dir')~=7, mkdir(crop_dir); end
SourceIndex=(1:24).'; OriginalFile=strings(24,1); CropFile=strings(24,1); OriginalHeight=zeros(24,1); OriginalWidth=zeros(24,1); CropRowStart=zeros(24,1); CropColStart=zeros(24,1);
for i=1:24
    name=sprintf('%02d.png',i); original_file=fullfile(original_dir,name); crop_file=fullfile(crop_dir,sprintf('kodim%02d_crop256.png',i));
    url=sprintf(['https://raw.githubusercontent.com/','MohamedBakrAli/Kodak-Lossless-True-Color-Image-Suite/','master/PhotoCD_PCD0992/%02d.png'],i);
    if exist(original_file,'file')~=2
        try, websave(original_file,url); catch ME, error('exp05:KodakDownload','Could not download Kodak image %02d. URL: %s MATLAB message: %s',i,url,ME.message); end
    end
    I=imread(original_file); h=size(I,1); w=size(I,2); if ndims(I)~=3||size(I,3)~=3, error('exp05:KodakRGB','Kodak %02d is not RGB.',i); end
    r0=floor((h-256)/2)+1; c0=floor((w-256)/2)+1; crop=I(r0:r0+255,c0:c0+255,:); if exist(crop_file,'file')~=2, imwrite(crop,crop_file); end
    OriginalFile(i)=string(original_file); CropFile(i)=string(crop_file); OriginalHeight(i)=h; OriginalWidth(i)=w; CropRowStart(i)=r0; CropColStart(i)=c0;
end
manifest=table(SourceIndex,OriginalFile,CropFile,OriginalHeight,OriginalWidth,CropRowStart,CropColStart); writetable(manifest,fullfile(crop_dir,'manifest.csv'));
end

function row=aggregate_rows(T,mask,dataset_name)
S=T(mask,:); if isempty(S), error('exp05:Aggregate','No rows for %s.',dataset_name); end
row=table(string(dataset_name),height(S),mean(S.PSNR_KPD),std(S.PSNR_KPD),min(S.PSNR_KPD),max(S.PSNR_KPD),mean(S.SSIM_KPD),std(S.SSIM_KPD),min(S.SSIM_KPD),max(S.SSIM_KPD),mean(S.EntropyPooled),std(S.EntropyPooled),mean(S.NPCRMean),std(S.NPCRMean),mean(S.UACIMean),std(S.UACIMean),mean(S.NPCRPassPct),mean(S.UACIPassPct),mean(S.JointPassPct),mean(S.EncPerGroupMean_ms),std(S.EncPerGroupMean_ms),mean(S.DecPerGroupMean_ms),std(S.DecPerGroupMean_ms),all(S.AllParametersBitExact),all(S.ReconstructionEquivalent),'VariableNames',{'Dataset','NumImages','PSNRMean','PSNRStd','PSNRMin','PSNRMax','SSIMMean','SSIMStd','SSIMMin','SSIMMax','EntropyMean','EntropyStd','NPCRMean','NPCRAcrossImageStd','UACIMean','UACIAcrossImageStd','NPCRPassPctMean','UACIPassPctMean','JointPassPctMean','EncPerGroupMean_ms','EncPerGroupAcrossImageStd_ms','DecPerGroupMean_ms','DecPerGroupAcrossImageStd_ms','AllParametersBitExact','AllReconstructionsEquivalent'});
end

function [NPCRCritical,UACILow,UACIHigh]=random_cipher_thresholds(L,alpha)
Q=255; z_npcr=-sqrt(2)*erfcinv(2*(1-alpha)); z_uaci=-sqrt(2)*erfcinv(2*(1-alpha/2));
NPCRCritical=(Q-z_npcr*sqrt(Q/L))/(Q+1)*100; mu_U=(Q+2)/(3*Q+3); sigma_U2=(Q+2)*(Q^2+2*Q+3)/(18*(Q+1)^2*Q*L);
UACILow=(mu_U-z_uaci*sqrt(sigma_U2))*100; UACIHigh=(mu_U+z_uaci*sqrt(sigma_U2))*100;
end

function [summary, capabilities] = run_exp06_controlled_baselines(image_file,K,num_rounds,runtime_repeats,differential_trials)
%RUN_EXP06_CONTROLLED_BASELINES Controlled direct/monolithic/group-wise comparison.
% The same 2D-LSCM core and round count are used for all three methods.

project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root); setup_paths(); cfg=default_config(project_root);
if nargin<1||isempty(image_file), image_file=cfg.baseline.default_image; end
if nargin<2||isempty(K), K=100; end
if nargin<3||isempty(num_rounds), num_rounds=3; end
if nargin<4||isempty(runtime_repeats), runtime_repeats=5; end
if nargin<5||isempty(differential_trials), differential_trials=30; end
[I,meta]=load_image_record(image_file);
if meta.channels~=1||meta.height~=256||meta.width~=256, error('exp06:Protocol','Exp06 uses one 256x256 grayscale image.'); end
n=get_partition_for_image(size(I),cfg); params_per_group=sum(n);
[rep,cache_file,~]=get_or_create_representation_cache(I,meta,n,K,cfg); %#ok<ASGLU>
if rep.channel{1}.K<K, error('exp06:K','Representation does not contain K groups.'); end
I_kpd=reconstruct_representation(rep,K); I_ref=uint8(I);
kpd_psnr=image_psnr(I_ref,clip_image_uint8(I_kpd)); kpd_ssim=image_ssim(I_ref,clip_image_uint8(I_kpd));
enc_cfg=cfg.encryption; enc_cfg.num_rounds=num_rounds;

% A. Direct image.
rng(cfg.seed+610001,'twister'); key_direct=make_group_key(num_rounds,cfg.encryption.a_max);
C_direct=encrypt_byte_block(uint8(I),key_direct,enc_cfg); P_direct=decrypt_byte_block(C_direct,key_direct,enc_cfg);
direct_exact=isequal(P_direct,uint8(I));
[entropy_direct,corr_direct]=cipher_stats(C_direct);
[npcr_direct,uaci_direct]=differential_byte_block(uint8(I),C_direct,key_direct,enc_cfg,differential_trials,cfg.seed+610101);

% B. Monolithic KPD parameters.
mono_param=zeros(params_per_group*K,1); ptr=1;
for k=1:K, p=concat_factors(rep.channel{1}.groups{k}); mono_param(ptr:ptr+numel(p)-1)=p; ptr=ptr+numel(p); end
rng(cfg.seed+620001,'twister'); key_mono=make_group_key(num_rounds,cfg.encryption.a_max);
[C_mono,~]=encrypt_group(mono_param,enc_cfg,key_mono); mono_dec=decrypt_group(C_mono,key_mono,enc_cfg); mono_exact=isequal(mono_param,mono_dec);
[entropy_mono,corr_mono]=cipher_stats(C_mono.bytes);
[npcr_mono,uaci_mono]=differential_serialized(mono_param,C_mono,key_mono,enc_cfg,differential_trials,cfg.seed+620101);

% C. Group-wise KPD parameters.
rng(cfg.seed+630001,'twister'); params=cell(K,1); keys=cell(K,1); ciphers=cell(K,1); exact=true;
for k=1:K
    params{k}=concat_factors(rep.channel{1}.groups{k}); keys{k}=make_group_key(num_rounds,cfg.encryption.a_max);
    [ciphers{k},~]=encrypt_group(params{k},enc_cfg,keys{k}); y=decrypt_group(ciphers{k},keys{k},enc_cfg); exact=exact&&isequal(y,params{k});
end
pool=[]; blocks=cell(K,1); for k=1:K, blocks{k}=ciphers{k}.bytes; pool=[pool;ciphers{k}.bytes(:)]; end %#ok<AGROW>
entropy_group=entropy_uint8(pool); corr_group=pooled_adjacent_correlation_uint8(blocks);
rng(cfg.seed+630101,'twister'); npcr_group=zeros(differential_trials,1); uaci_group=zeros(differential_trials,1);
for t=1:differential_trials
    g=randi(K); [B,meta_ser]=serialize_group(params{g}); pos=randi(meta_ser.byte_len); B(pos)=bitxor(B(pos),uint8(1)); p2=deserialize_group(B,meta_ser);
    [C2,~]=encrypt_group(p2,enc_cfg,keys{g}); [npcr_group(t),uaci_group(t)]=npcr_uaci(ciphers{g}.bytes,C2.bytes);
end

% Runtime with identical timing boundary: encryption/decryption only.
enc_direct=timeit_repeat(@()encrypt_byte_block(uint8(I),key_direct,enc_cfg),runtime_repeats);
dec_direct=timeit_repeat(@()decrypt_byte_block(C_direct,key_direct,enc_cfg),runtime_repeats);
enc_mono=timeit_repeat(@()encrypt_group(mono_param,enc_cfg,key_mono),runtime_repeats);
dec_mono=timeit_repeat(@()decrypt_group(C_mono,key_mono,enc_cfg),runtime_repeats);
enc_group=timeit_repeat(@()encrypt_all_groups(params,keys,enc_cfg),runtime_repeats);
dec_group=timeit_repeat(@()decrypt_all_groups(ciphers,keys,enc_cfg),runtime_repeats);

Method=["Direct image";"Monolithic KPD";"Group-wise KPD"];
CipherBytes=[numel(C_direct);numel(C_mono.bytes);sum(cellfun(@(c)numel(c.bytes),ciphers))];
Entropy=[entropy_direct;entropy_mono;entropy_group]; CorrH=[corr_direct.horizontal;corr_mono.horizontal;corr_group.horizontal]; CorrV=[corr_direct.vertical;corr_mono.vertical;corr_group.vertical]; CorrD=[corr_direct.diagonal;corr_mono.diagonal;corr_group.diagonal];
NPCRMean=[mean(npcr_direct);mean(npcr_mono);mean(npcr_group)]; UACIMean=[mean(uaci_direct);mean(uaci_mono);mean(uaci_group)];
EncMean_ms=1000*[mean(enc_direct);mean(enc_mono);mean(enc_group)]; DecMean_ms=1000*[mean(dec_direct);mean(dec_mono);mean(dec_group)];
ExactRecovery=[direct_exact;mono_exact;exact];
summary=table(Method,CipherBytes,Entropy,CorrH,CorrV,CorrD,NPCRMean,UACIMean,EncMean_ms,DecMean_ms,ExactRecovery,repmat(kpd_psnr,3,1),repmat(kpd_ssim,3,1),'VariableNames',{'Method','CipherBytes','Entropy','CorrH','CorrV','CorrD','NPCRMean','UACIMean','EncMean_ms','DecMean_ms','ExactRecovery','KPD_PSNR','KPD_SSIM'});
capabilities=table(Method,[false;false;true],[false;false;true],[false;false;true],[1;1;K],'VariableNames',{'Method','IndependentGroupKeys','SelectiveGroupDecryption','ProgressivePrefixAuthorization','ProtectionUnits'});
if exist(cfg.results.tables,'dir')~=7, mkdir(cfg.results.tables); end
writetable(summary,fullfile(cfg.results.tables,'exp06_controlled_baselines_summary.csv'));
writetable(capabilities,fullfile(cfg.results.tables,'exp06_controlled_baselines_capabilities.csv'));
end

function C=encrypt_byte_block(P,key,cfg)
P=uint8(P); [M,N]=size(P); x=key.x0; y=key.y0;
for r=1:key.num_rounds, th=mod(key.theta*double(key.a(r)),1); th=max(2^-52,min(1-2^-52,th)); [S,R,x,y]=lscm_generate(x,y,th,M,N,cfg.warmup); P=diffuse_2d(permute_2d(P,S),R); end
C=P;
end
function P=decrypt_byte_block(C,key,cfg)
[M,N]=size(C); x=key.x0; y=key.y0; S=cell(key.num_rounds,1); R=cell(key.num_rounds,1);
for r=1:key.num_rounds, th=mod(key.theta*double(key.a(r)),1); th=max(2^-52,min(1-2^-52,th)); [S{r},R{r},x,y]=lscm_generate(x,y,th,M,N,cfg.warmup); end
P=C; for r=key.num_rounds:-1:1, P=inverse_permute_2d(inverse_diffuse_2d(P,R{r}),S{r}); end
end
function [H,c]=cipher_stats(C), H=entropy_uint8(C); c=pooled_adjacent_correlation_uint8(C); end
function [n,u]=differential_byte_block(P,C,key,cfg,T,seed)
rng(seed,'twister'); n=zeros(T,1);u=zeros(T,1); for t=1:T, Q=P; j=randi(numel(Q)); Q(j)=bitxor(Q(j),uint8(1)); C2=encrypt_byte_block(Q,key,cfg); [n(t),u(t)]=npcr_uaci(C,C2); end
end
function [n,u]=differential_serialized(p,C,key,cfg,T,seed)
[B,m]=serialize_group(p); rng(seed,'twister'); n=zeros(T,1);u=zeros(T,1); for t=1:T, Q=B; j=randi(m.byte_len); Q(j)=bitxor(Q(j),uint8(1)); p2=deserialize_group(Q,m); [C2,~]=encrypt_group(p2,cfg,key); [n(t),u(t)]=npcr_uaci(C.bytes,C2.bytes); end
end
function times=timeit_repeat(fun,T), times=zeros(T,1); for t=1:T, tic; fun(); times(t)=toc; end, end
function encrypt_all_groups(p,k,c), for i=1:numel(p), encrypt_group(p{i},c,k{i}); end, end
function decrypt_all_groups(x,k,c), for i=1:numel(x), decrypt_group(x{i},k{i},c); end, end

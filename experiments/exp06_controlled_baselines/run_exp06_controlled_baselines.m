function [summary, capabilities] = run_exp06_controlled_baselines(image_file,K,num_rounds,runtime_repeats,differential_trials)
%RUN_EXP06_CONTROLLED_BASELINES Controlled direct/monolithic/group-wise comparison.
% All methods use the same 2D-LSCM core and the same number of rounds.

project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root); setup_paths(); cfg=default_config(project_root);
if nargin<1||isempty(image_file), image_file=cfg.baseline.default_image; end
if nargin<2||isempty(K), K=100; end
if nargin<3||isempty(num_rounds), num_rounds=3; end
if nargin<4||isempty(runtime_repeats), runtime_repeats=5; end
if nargin<5||isempty(differential_trials), differential_trials=30; end
[I,meta]=load_image_record(image_file);
if meta.channels~=1||meta.height~=256||meta.width~=256, error('exp06:Protocol','Exp06 uses one 256x256 grayscale image.'); end
n=get_partition_for_image(size(I),cfg); params_per_group=sum(n); parameter_rate_pct=params_per_group*K/(meta.height*meta.width)*100;
[rep,~,~]=get_or_create_representation_cache(I,meta,n,K,cfg);
if rep.channel{1}.K<K, error('exp06:K','Representation does not contain K groups.'); end
I_ref=uint8(I); I_kpd=reconstruct_representation(rep,K); I_kpd_u8=clip_image_uint8(I_kpd);
kpd_psnr=image_psnr(I_ref,I_kpd_u8); kpd_ssim=image_ssim(I_ref,I_kpd_u8);
enc_cfg=cfg.encryption; enc_cfg.num_rounds=num_rounds;

%% A. Direct image encryption.
P_direct=uint8(I); rng(cfg.seed+610001,'twister'); key_direct=make_group_key(num_rounds,cfg.encryption.a_max);
C_direct=encrypt_byte_block(P_direct,key_direct,enc_cfg); P_direct_dec=decrypt_byte_block(C_direct,key_direct,enc_cfg);
direct_exact=isequal(P_direct_dec,P_direct); entropy_direct=entropy_uint8(C_direct); corr_direct=pooled_adjacent_correlation_uint8(C_direct);
[npcr_direct,uaci_direct]=differential_byte_block(P_direct,C_direct,key_direct,enc_cfg,differential_trials,cfg.seed+610101);
[crit_d,lo_d,hi_d]=random_cipher_thresholds(numel(C_direct),0.05);

%% B. Monolithic KPD encryption.
mono_param=zeros(params_per_group*K,1); ptr=1;
for k=1:K, p=concat_factors(rep.channel{1}.groups{k}); mono_param(ptr:ptr+numel(p)-1)=p; ptr=ptr+numel(p); end
[mono_plain_block,mono_ser]=serialize_group(mono_param); rng(cfg.seed+620001,'twister'); key_mono=make_group_key(num_rounds,cfg.encryption.a_max);
[C_mono,~]=encrypt_group(mono_param,enc_cfg,key_mono); mono_dec=decrypt_group(C_mono,key_mono,enc_cfg); mono_exact=isequal(mono_param,mono_dec);
rep_mono=rep; ptr=1; for k=1:K, p=mono_dec(ptr:ptr+params_per_group-1); rep_mono.channel{1}.groups{k}=split_factors(p,n); ptr=ptr+params_per_group; end
mono_recon=isequal(reconstruct_representation(rep_mono,K),I_kpd); entropy_mono=entropy_uint8(C_mono.bytes); corr_mono=pooled_adjacent_correlation_uint8(C_mono.bytes);
[npcr_mono,uaci_mono]=differential_serialized(mono_param,mono_plain_block,mono_ser,C_mono,key_mono,enc_cfg,differential_trials,cfg.seed+620101);
[crit_m,lo_m,hi_m]=random_cipher_thresholds(numel(C_mono.bytes),0.05);

%% C. Group-wise KPD encryption.
rng(cfg.seed+630001,'twister'); params=cell(K,1); keys=cell(K,1); ciphers=cell(K,1); dec_groups=cell(K,1); group_exact=true;
for k=1:K
    params{k}=concat_factors(rep.channel{1}.groups{k}); keys{k}=make_group_key(num_rounds,cfg.encryption.a_max);
    [ciphers{k},~]=encrypt_group(params{k},enc_cfg,keys{k}); y=decrypt_group(ciphers{k},keys{k},enc_cfg);
    group_exact=group_exact&&isequal(y,params{k}); dec_groups{k}=split_factors(y,n);
end
group_recon=isequal(reconstruct_group_subset(dec_groups,rep.image_size,1:K),I_kpd);
blocks=cellfun(@(c)c.bytes,ciphers,'UniformOutput',false); pool=vertcat(blocks{:}); entropy_group=entropy_uint8(pool); corr_group=pooled_adjacent_correlation_uint8(blocks);
rng(cfg.seed+630101,'twister'); npcr_group=zeros(differential_trials,1); uaci_group=zeros(differential_trials,1);
for t=1:differential_trials
    g=randi(K); [B,s]=serialize_group(params{g}); pos=randi(s.byte_len); B(pos)=bitxor(B(pos),uint8(1)); p2=deserialize_group(B,s);
    [C2,~]=encrypt_group(p2,enc_cfg,keys{g}); [npcr_group(t),uaci_group(t)]=npcr_uaci(ciphers{g}.bytes,C2.bytes);
end
[crit_g,lo_g,hi_g]=random_cipher_thresholds(numel(ciphers{1}.bytes),0.05);

%% Runtime (decomposition, cache loading, key generation excluded).
enc_d=time_repeat(@()encrypt_byte_block(P_direct,key_direct,enc_cfg),runtime_repeats); dec_d=time_repeat(@()decrypt_byte_block(C_direct,key_direct,enc_cfg),runtime_repeats);
enc_m=time_repeat(@()encrypt_group(mono_param,enc_cfg,key_mono),runtime_repeats); dec_m=time_repeat(@()decrypt_group(C_mono,key_mono,enc_cfg),runtime_repeats);
enc_g=time_repeat(@()encrypt_all(params,keys,enc_cfg),runtime_repeats); dec_g=time_repeat(@()decrypt_all(ciphers,keys,enc_cfg),runtime_repeats);

Method=["Direct image";"Monolithic KPD";"Group-wise KPD"];
ProtectedDomain=["Raw uint8 image";sprintf("First %d CLSA-KPD groups as one stream",K);sprintf("First %d CLSA-KPD groups as independent blocks",K)];
NumProtectionUnits=[1;1;K]; NumIndependentKeys=[1;1;K]; PlainBytes=[numel(P_direct);mono_ser.byte_len;K*numel(ciphers{1}.bytes)]; CipherBytes=[numel(C_direct);numel(C_mono.bytes);K*numel(ciphers{1}.bytes)]; DifferentialUnitBytes=[numel(C_direct);numel(C_mono.bytes);numel(ciphers{1}.bytes)]; ParameterRatePct=[NaN;parameter_rate_pct;parameter_rate_pct];
EntropyPooled=[entropy_direct;entropy_mono;entropy_group]; CorrH=[corr_direct.horizontal;corr_mono.horizontal;corr_group.horizontal]; CorrV=[corr_direct.vertical;corr_mono.vertical;corr_group.vertical]; CorrD=[corr_direct.diagonal;corr_mono.diagonal;corr_group.diagonal];
npcrs={npcr_direct,npcr_mono,npcr_group}; uacis={uaci_direct,uaci_mono,uaci_group}; crit=[crit_d;crit_m;crit_g]; lo=[lo_d;lo_m;lo_g]; hi=[hi_d;hi_m;hi_g];
NPCRMean=zeros(3,1);NPCRStd=zeros(3,1);NPCRMin=zeros(3,1);NPCRMax=zeros(3,1);UACIMean=zeros(3,1);UACIStd=zeros(3,1);UACIMin=zeros(3,1);UACIMax=zeros(3,1);NPCRPassPct=zeros(3,1);UACIPassPct=zeros(3,1);JointPassPct=zeros(3,1);
for i=1:3
    a=npcrs{i}; b=uacis{i}; NPCRMean(i)=mean(a);NPCRStd(i)=std(a,0);NPCRMin(i)=min(a);NPCRMax(i)=max(a);UACIMean(i)=mean(b);UACIStd(i)=std(b,0);UACIMin(i)=min(b);UACIMax(i)=max(b);
    pa=a>crit(i); pb=b>lo(i)&b<hi(i); NPCRPassPct(i)=mean(pa)*100;UACIPassPct(i)=mean(pb)*100;JointPassPct(i)=mean(pa&pb)*100;
end
EncTotalMean_ms=1000*[mean(enc_d);mean(enc_m);mean(enc_g)]; EncTotalStd_ms=1000*[std(enc_d,0);std(enc_m,0);std(enc_g,0)]; DecTotalMean_ms=1000*[mean(dec_d);mean(dec_m);mean(dec_g)]; DecTotalStd_ms=1000*[std(dec_d,0);std(dec_m,0);std(dec_g,0)];
EncThroughput_MBps=(PlainBytes/1e6)./(EncTotalMean_ms/1000); DecThroughput_MBps=(PlainBytes/1e6)./(DecTotalMean_ms/1000);
ProtectedDomainExactRecovery=[direct_exact;mono_exact;group_exact]; ImageReconstructionEquivalent=[direct_exact;mono_recon;group_recon]; ReconstructionPSNR_dB=[Inf;kpd_psnr;kpd_psnr]; ReconstructionSSIM=[1;kpd_ssim;kpd_ssim];
NPCRCritical=crit;UACILow=lo;UACIHigh=hi;
summary=table(Method,ProtectedDomain,NumProtectionUnits,NumIndependentKeys,PlainBytes,CipherBytes,DifferentialUnitBytes,ParameterRatePct,EntropyPooled,CorrH,CorrV,CorrD,NPCRMean,NPCRStd,NPCRMin,NPCRMax,UACIMean,UACIStd,UACIMin,UACIMax,NPCRCritical,UACILow,UACIHigh,NPCRPassPct,UACIPassPct,JointPassPct,EncTotalMean_ms,EncTotalStd_ms,DecTotalMean_ms,DecTotalStd_ms,EncThroughput_MBps,DecThroughput_MBps,ProtectedDomainExactRecovery,ImageReconstructionEquivalent,ReconstructionPSNR_dB,ReconstructionSSIM);

UsesOrderedKPDRepresentation=[false;true;true]; IndependentGroupProtection=[false;false;true]; SelectiveGroupAuthorization=[false;false;true]; ProgressiveKeyRelease=[false;false;true]; PartialGroupRecoveryWithoutOtherKeys=[false;false;true]; AccessGranularity=["Whole image";"Whole KPD stream";"Individual ordered KPD group"]; Tradeoff=["No KPD representation; one protection unit";"Keeps KPD representation but removes group-level access";"Adds key/protection-unit overhead for fine-grained access"];
capabilities=table(Method,UsesOrderedKPDRepresentation,IndependentGroupProtection,SelectiveGroupAuthorization,ProgressiveKeyRelease,PartialGroupRecoveryWithoutOtherKeys,AccessGranularity,Tradeoff);
if exist(cfg.results.tables,'dir')~=7, mkdir(cfg.results.tables); end
writetable(summary,fullfile(cfg.results.tables,'exp06_controlled_baselines_summary.csv')); writetable(capabilities,fullfile(cfg.results.tables,'exp06_controlled_baselines_capabilities.csv'));
end

function C=encrypt_byte_block(P,key,cfg)
P=uint8(P);[M,N]=size(P);x=key.x0;y=key.y0;for r=1:key.num_rounds,th=max(2^-52,min(1-2^-52,mod(key.theta*double(key.a(r)),1)));[S,R,x,y]=lscm_generate(x,y,th,M,N,cfg.warmup);P=diffuse_2d(permute_2d(P,S),R);end;C=P;
end
function P=decrypt_byte_block(C,key,cfg)
[M,N]=size(C);x=key.x0;y=key.y0;S=cell(key.num_rounds,1);R=cell(key.num_rounds,1);for r=1:key.num_rounds,th=max(2^-52,min(1-2^-52,mod(key.theta*double(key.a(r)),1)));[S{r},R{r},x,y]=lscm_generate(x,y,th,M,N,cfg.warmup);end;P=C;for r=key.num_rounds:-1:1,P=inverse_permute_2d(inverse_diffuse_2d(P,R{r}),S{r});end
end
function [n,u]=differential_byte_block(P,C,key,cfg,T,seed),rng(seed,'twister');n=zeros(T,1);u=zeros(T,1);for t=1:T,Q=P;j=randi(numel(Q));Q(j)=bitxor(Q(j),uint8(1));C2=encrypt_byte_block(Q,key,cfg);[n(t),u(t)]=npcr_uaci(C,C2);end,end
function [n,u]=differential_serialized(p,B,s,C,key,cfg,T,seed),rng(seed,'twister');n=zeros(T,1);u=zeros(T,1);for t=1:T,Q=B;j=randi(s.byte_len);Q(j)=bitxor(Q(j),uint8(1));p2=deserialize_group(Q,s);[C2,~]=encrypt_group(p2,cfg,key);[n(t),u(t)]=npcr_uaci(C.bytes,C2.bytes);end,end
function times=time_repeat(fun,T),times=zeros(T,1);for t=1:T,tic;fun();times(t)=toc;end,end
function encrypt_all(p,k,c),for i=1:numel(p),encrypt_group(p{i},c,k{i});end,end
function decrypt_all(x,k,c),for i=1:numel(x),decrypt_group(x{i},k{i},c);end,end
function [crit,lo,hi]=random_cipher_thresholds(L,alpha),Q=255;z1=-sqrt(2)*erfcinv(2*(1-alpha));z2=-sqrt(2)*erfcinv(2*(1-alpha/2));crit=(Q-z1*sqrt(Q/L))/(Q+1)*100;mu=(Q+2)/(3*Q+3);v=(Q+2)*(Q^2+2*Q+3)/(18*(Q+1)^2*Q*L);lo=(mu-z2*sqrt(v))*100;hi=(mu+z2*sqrt(v))*100;end

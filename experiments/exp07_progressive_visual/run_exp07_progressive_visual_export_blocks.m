function summary = run_exp07_progressive_visual_export_blocks()
%RUN_EXP07_PROGRESSIVE_VISUAL_EXPORT_BLOCKS Export full/ROI blocks for Fig. 7.
% The final multi-panel layout is assembled in LaTeX.

project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root); setup_paths(); cfg=default_config(project_root);
K_total=300; q_values=[25 50 100 200 300]; R=3;
image_files={fullfile(project_root,'data','USC_SIPI','gray_256','5.1.12.tiff'),fullfile(project_root,'data','USC_SIPI','gray_256','5.1.14.tiff'),fullfile(project_root,'data','USC_SIPI','color_256','4.1.04.tiff')};
short_names={'clock','aerial','portrait'}; display_names={'Clock','Aerial','Portrait'};
roi_list=[136 55 82 82;112 124 88 88;108 48 94 94];
base_dir=fullfile(cfg.results.images,'exp07_visual_blocks'); if exist(base_dir,'dir')~=7, mkdir(base_dir); end
Image=strings(0,1); Variant=strings(0,1); Q=zeros(0,1); EtaPct=zeros(0,1); PSNR=zeros(0,1); SSIM=zeros(0,1); BitExact=false(0,1); File=strings(0,1);

for im_idx=1:numel(image_files)
    [I,meta]=load_image_record(image_files{im_idx});
    if meta.height~=256||meta.width~=256, error('exp07:Size','Exp07 expects 256x256 images.'); end
    n=get_partition_for_image(size(I),cfg); eta=q_values*sum(n)/(meta.height*meta.width)*100;
    [rep,~,~]=get_or_create_representation_cache(I,meta,n,K_total,cfg);
    if min(cellfun(@(c)c.K,rep.channel))<K_total, error('exp07:K','Representation does not contain K=300.'); end
    enc_cfg=cfg.encryption; enc_cfg.num_rounds=R; dec_groups=cell(meta.channels,1); all_exact=true;
    rng(cfg.seed+900000+10000*im_idx,'twister');
    for ch=1:meta.channels
        dec_groups{ch}=cell(K_total,1);
        for k=1:K_total
            p=concat_factors(rep.channel{ch}.groups{k}); key=make_group_key(R,cfg.encryption.a_max);
            [cipher,key]=encrypt_group(p,enc_cfg,key); p2=decrypt_group(cipher,key,enc_cfg); all_exact=all_exact&&isequal(p,p2);
            dec_groups{ch}{k}=split_factors(p2,n);
        end
    end
    out=fullfile(base_dir,short_names{im_idx}); if exist(out,'dir')~=7, mkdir(out); end
    Iref=uint8(I); roi=roi_list(im_idx,:);
    save_block(Iref,roi,fullfile(out,'original_full.png'),fullfile(out,'original_zoom.png'));
    append_row(display_names{im_idx},'Original',NaN,NaN,Inf,1,true,fullfile(out,'original_full.png'));
    for j=1:numel(q_values)
        q=q_values(j); Rimg=reconstruct_channels(dec_groups,[meta.height meta.width],1:q); U=clip_image_uint8(Rimg);
        p=image_psnr(Iref,U); s=image_ssim(Iref,U);
        ff=fullfile(out,sprintf('q%03d_full.png',q)); zf=fullfile(out,sprintf('q%03d_zoom.png',q)); save_block(U,roi,ff,zf);
        append_row(display_names{im_idx},sprintf('q=%d',q),q,eta(j),p,s,all_exact,ff);
    end
end
summary=table(Image,Variant,Q,EtaPct,PSNR,SSIM,BitExact,File);
if exist(cfg.results.tables,'dir')~=7, mkdir(cfg.results.tables); end
writetable(summary,fullfile(cfg.results.tables,'exp07_progressive_three_images_summary.csv'));

    function append_row(img,var,q,eta,p,s,e,f)
        Image(end+1,1)=string(img); Variant(end+1,1)=string(var); Q(end+1,1)=q; EtaPct(end+1,1)=eta; PSNR(end+1,1)=p; SSIM(end+1,1)=s; BitExact(end+1,1)=e; File(end+1,1)=string(f);
    end
end

function Irec=reconstruct_channels(groups,sz,idx)
c=numel(groups); Irec=zeros(sz(1),sz(2),c); for ch=1:c, Irec(:,:,ch)=reconstruct_group_subset(groups{ch},sz,idx); end
if c==1, Irec=Irec(:,:,1); end
end

function save_block(I,roi,full_file,zoom_file)
U=uint8(I); x=roi(1); y=roi(2); w=roi(3); h=roi(4);
Ubox=draw_rect(U,x,y,w,h); imwrite(imresize(Ubox,[512 512],'nearest'),full_file);
Z=U(y:min(y+h,size(U,1)),x:min(x+w,size(U,2)),:); Z=imresize(Z,[512 512],'nearest'); Z=draw_border(Z,4); imwrite(Z,zoom_file);
end
function U=draw_rect(U,x,y,w,h)
if ndims(U)==2, U=repmat(U,1,1,3); end
x1=max(1,x);x2=min(size(U,2),x+w);y1=max(1,y);y2=min(size(U,1),y+h);t=3;
for d=0:t-1
    U(max(1,y1-d),x1:x2,1)=230;U(max(1,y1-d),x1:x2,2:3)=20;
    U(min(size(U,1),y2+d),x1:x2,1)=230;U(min(size(U,1),y2+d),x1:x2,2:3)=20;
    U(y1:y2,max(1,x1-d),1)=230;U(y1:y2,max(1,x1-d),2:3)=20;
    U(y1:y2,min(size(U,2),x2+d),1)=230;U(y1:y2,min(size(U,2),x2+d),2:3)=20;
end
end
function U=draw_border(U,t)
if ndims(U)==2, U=repmat(U,1,1,3); end
U(1:t,:,1)=230;U(1:t,:,2:3)=20;U(end-t+1:end,:,1)=230;U(end-t+1:end,:,2:3)=20;U(:,1:t,1)=230;U(:,1:t,2:3)=20;U(:,end-t+1:end,1)=230;U(:,end-t+1:end,2:3)=20;
end

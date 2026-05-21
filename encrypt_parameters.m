%% encrypt_parameters.m
clear; clc;

% ========== 分解参数 ==========
n = [64, 32, 32];
img_path = 'image2.bmp';
max_iter = 300;               % 演示用
error_threshold = 1e-4;

% ========== 加密参数 ==========
P_rounds = 4;                 % 置乱轮数
D_rounds = 4;                 % 扩散轮数 (每轮 = 行扩散+列扩散)
img_size = [32, 32];          % 重组后的字节图像尺寸 (32×32 = 1024 字节)

% ========== 读取图像并向量化 ==========
img_ori = imread(img_path);
if size(img_ori,3) == 3
    img_gray = rgb2gray(img_ori);
else
    img_gray = img_ori;
end
img_256 = imresize(img_gray, [256 256]);
V = double(img_256(:));

% ========== CLSA 分解 ==========
v = {V};
BigArray = cell(max_iter, 1);
cipher_data = cell(max_iter, 1);
key_data = cell(max_iter, 1);

fprintf('开始分解并加密 (置乱 %d 轮, 扩散 %d 轮) ...\n', P_rounds, D_rounds);
for k = 1:max_iter
    % 随机初始化
    x1 = 6*rand(n(1),1);
    x2 = 6*rand(n(2),1);
    x3 = 6*rand(n(3),1);
    BigArray{k} = {x1, x2, x3};
    
    % CLSA 内部优化
    while true
        a = kronn(BigArray{k}{1}, BigArray{k}{2}, BigArray{k}{3});
        for j = 1:numel(n)
            BigArray{k}{j} = opt(n, j, v{k}, BigArray{k});
        end
        b = kronn(BigArray{k}{1}, BigArray{k}{2}, BigArray{k}{3});
        if norm(a-b) < 0.1
            break;
        end
    end
    
    % 更新残差
    current_term = kronn(BigArray{k}{1}, BigArray{k}{2}, BigArray{k}{3});
    v{k+1} = v{k} - current_term;
    
    % ---- 加密当前组参数 ----
    param_vec = [BigArray{k}{1}; BigArray{k}{2}; BigArray{k}{3}];
    
    % 生成独立密钥
   key.x0 = rand();
key.y0 = rand();
key.theta = rand();

key.rounds = P_rounds;
key.P = P_rounds;
key.D = D_rounds;

key.a = uint32(randi([1, 2^25 - 1], 1, key.rounds));

key.param_len = numel(param_vec);
key.byte_len = numel(typecast(param_vec(:)', 'uint8'));
    
    % 加密
    cipher_bytes = encrypt_params(param_vec, key, img_size);
    cipher_data{k} = cipher_bytes;
    key_data{k} = key;
    
    fprintf('Iter %3d  加密完成\n', k);
    
    if norm(v{k+1}) < error_threshold
        break;
    end
end

cipher_data = cipher_data(1:k);
key_data = key_data(1:k);

save('encrypted_params.mat', 'cipher_data', 'key_data', 'n', 'v', 'img_size', 'P_rounds', 'D_rounds');
fprintf('加密完成，共 %d 组参数已保存至 encrypted_params.mat\n', k);
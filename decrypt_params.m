
function param_vec = decrypt_params(cipher_bytes, key, img_size)
    P = reshape(uint8(cipher_bytes), img_size);
    [M, N] = size(P);

    x0 = key.x0;
    y0 = key.y0;
    theta0 = key.theta;

    if isfield(key, 'rounds')
        rounds = key.rounds;
    elseif isfield(key, 'P')
        rounds = key.P;
    else
        rounds = 4;
    end

    if isfield(key, 'a')
        a = double(key.a(:)');
    else
        a = ones(1, rounds);
    end

    if numel(a) < rounds
        error('key.a 的长度不足，至少需要 %d 个扰动系数。', rounds);
    end

    S_cell = cell(rounds, 1);
    R_cell = cell(rounds, 1);

    x = x0;
    y = y0;

    % 按加密顺序重新生成每轮 S、R
    for r = 1:rounds
        theta_r = mod(theta0 * a(r), 1);

        if theta_r <= 0
            theta_r = 2^-52;
        elseif theta_r >= 1
            theta_r = 1 - 2^-52;
        end

        [S_cell{r}, R_cell{r}, x, y] = lscm_generate_matrices(x, y, theta_r, M, N);
    end

    % 倒序解密
    for r = rounds:-1:1
        P = inverse_diffuse_2D(P, R_cell{r});
        P = inverse_permute_2D(P, S_cell{r});
    end

    bytes = P(:)';

    % 去掉加密时补的 0
    if isfield(key, 'byte_len')
        bytes = bytes(1:key.byte_len);
    end

    param_vec = typecast(bytes, 'double');
    param_vec = param_vec(:);

    % 双重保险：只保留原始参数长度
    if isfield(key, 'param_len')
        param_vec = param_vec(1:key.param_len);
    end
end
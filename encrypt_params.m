function cipher_bytes = encrypt_params(param_vec, key, img_size)
    % 将参数向量转成 uint8 字节
    bytes = typecast(param_vec(:)', 'uint8');

    total_bytes = prod(img_size);

    % 如果参数字节数小于 img_size 容器，则补 0
    if numel(bytes) < total_bytes
        bytes = [bytes, zeros(1, total_bytes - numel(bytes), 'uint8')];
    elseif numel(bytes) > total_bytes
        error('参数字节数为 %d，但 img_size 只能容纳 %d 字节，请增大 img_size。', ...
              numel(bytes), total_bytes);
    end

    P = reshape(bytes, img_size);
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

    % 如果 key 中没有 a，则兼容旧代码，自动使用全 1
    if isfield(key, 'a')
        a = double(key.a(:)');
    else
        a = ones(1, rounds);
    end

    if numel(a) < rounds
        error('key.a 的长度不足，至少需要 %d 个扰动系数。', rounds);
    end

    x = x0;
    y = y0;

    for r = 1:rounds
        theta_r = mod(theta0 * a(r), 1);

        % 避免 theta_r 落到 0 或 1
        if theta_r <= 0
            theta_r = 2^-52;
        elseif theta_r >= 1
            theta_r = 1 - 2^-52;
        end

        % 注意：这里要求 lscm_generate_matrices 返回 x_last, y_last
        [S, R, x, y] = lscm_generate_matrices(x, y, theta_r, M, N);

        P = permute_2D(P, S);
        P = diffuse_2D(P, R);
    end

    cipher_bytes = P(:)';
end
function [S, R, x_last, y_last] = lscm_generate_matrices(x0, y0, theta, M, N)
%LSCM_GENERATE_MATRICES Generate permutation matrix S and diffusion matrix R.
%
% 输出:
%   S      : M x N double chaotic matrix for permutation
%   R      : M x N uint8 chaotic matrix for diffusion
%   x_last : 本轮迭代结束后的 x 状态
%   y_last : 本轮迭代结束后的 y 状态

    WARMUP = 500;
    total_len = 2 * M * N;

    X = zeros(1, WARMUP + total_len + 1);
    Y = zeros(1, WARMUP + total_len + 1);

    X(1) = x0;
    Y(1) = y0;

    for i = 1:(WARMUP + total_len)
        X(i+1) = sin(pi * ( ...
            4 * theta * X(i) * (1 - X(i)) + ...
            (1 - theta) * sin(pi * Y(i)) ...
        ));

        Y(i+1) = sin(pi * ( ...
            4 * theta * Y(i) * (1 - Y(i)) + ...
            (1 - theta) * sin(pi * X(i+1)) ...
        ));
    end

    % 本轮最终状态，用于下一轮初值
    x_last = X(end);
    y_last = Y(end);

    % 丢弃预热段
    X_use = X(WARMUP + 2 : WARMUP + 1 + total_len);
    Y_use = Y(WARMUP + 2 : WARMUP + 1 + total_len);

    % 前 M*N 个 X 用于置乱
    S_seq = X_use(1 : M*N);

    % 后 M*N 个 Y 用于扩散
    R_seq = Y_use(M*N + 1 : 2*M*N);

    S = reshape(S_seq, M, N);

    R = mod(floor(R_seq * 2^32), 256);
    R = uint8(reshape(R, M, N));
end
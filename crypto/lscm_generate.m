function [S, R, x_last, y_last] = lscm_generate(x0, y0, theta, M, N, warmup)
%LSCM_GENERATE Generate permutation and diffusion matrices from 2D-LSCM.

if nargin < 6 || isempty(warmup)
    warmup = 500;
end

total_len = 2 * M * N;
X = zeros(1, warmup + total_len + 1);
Y = zeros(1, warmup + total_len + 1);
X(1) = x0;
Y(1) = y0;

for i = 1:(warmup + total_len)
    X(i+1) = sin(pi * ( ...
        4 * theta * X(i) * (1 - X(i)) + ...
        (1 - theta) * sin(pi * Y(i))));

    Y(i+1) = sin(pi * ( ...
        4 * theta * Y(i) * (1 - Y(i)) + ...
        (1 - theta) * sin(pi * X(i+1))));
end

x_last = X(end);
y_last = Y(end);
X_use = X(warmup + 2 : warmup + 1 + total_len);
Y_use = Y(warmup + 2 : warmup + 1 + total_len);

S = reshape(X_use(1:M*N), M, N);
R_seq = Y_use(M*N + 1 : 2*M*N);
R = mod(floor(R_seq * 2^32), 256);
R = uint8(reshape(R, M, N));
end

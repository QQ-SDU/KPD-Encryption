function P_diff = diffuse_2D(P, R)
    % R 是 uint8 密钥流矩阵 (M x N)，由 floor(Y * 2^32) mod 256 生成
    [M, N] = size(P);
    Q = double(P);
    % 行扩散
    for i = 1:M
        row = Q(i,:);
        G = N;
        new_row = zeros(1, G);
        new_row(1) = mod(row(1) + row(G) + row(G-1) + double(R(i,1)), 256);
        new_row(2) = mod(row(2) + new_row(1) + row(G) + double(R(i,2)), 256);
        for j = 3:G
            new_row(j) = mod(row(j) + new_row(j-1) + new_row(j-2) + double(R(i,j)), 256);
        end
        Q(i,:) = new_row;
    end
    % 列扩散
    for j = 1:N
        col = Q(:,j)';
        G = M;
        new_col = zeros(1, G);
        new_col(1) = mod(col(1) + col(G) + col(G-1) + double(R(1,j)), 256);
        new_col(2) = mod(col(2) + new_col(1) + col(G) + double(R(2,j)), 256);
        for i = 3:G
            new_col(i) = mod(col(i) + new_col(i-1) + new_col(i-2) + double(R(i,j)), 256);
        end
        Q(:,j) = new_col';
    end
    P_diff = uint8(Q);
end
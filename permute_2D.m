function P_perm = permute_2D(P, S)
    % 使用混沌矩阵 S 对图像 P 进行行列同步置乱
    % 输入: P - uint8 矩阵 (M x N)
    %       S - double 混沌矩阵 (M x N)
    [M, N] = size(P);
    [~, O] = sort(S, 1);          % 每列排序，O 是行索引
    T = zeros(M, N, 'uint8');
    for i = 1:M
        pos = sub2ind([M,N], O(i,:), 1:N);
        vals = P(pos);
        s_vals = S(pos);
        [~, v] = sort(s_vals);    % 对该行混沌值排序
        T(pos) = vals(v);         % 按排序位置重排像素
    end
    P_perm = T;
end

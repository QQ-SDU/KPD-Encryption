function P = inverse_diffuse_2d(C, R)
%INVERSE_DIFFUSE_2D Exact inverse of diffuse_2d.

C = uint8(C);
R = uint8(R);
[M, N] = size(C);
if ~isequal(size(R), [M, N])
    error('inverse_diffuse_2d:Size', 'C and R must have identical sizes.');
end
if M < 3 || N < 3
    error('inverse_diffuse_2d:MinimumSize', 'Both matrix dimensions must be at least 3.');
end

Q = double(C);

% Invert column diffusion first.
for j = 1:N
    col = Q(:,j).';
    G = M;
    orig_col = zeros(1, G);
    orig_col(G)   = mod(col(G)   - col(G-1) - col(G-2) - double(R(G,j)), 256);
    orig_col(G-1) = mod(col(G-1) - col(G-2) - col(G-3) - double(R(G-1,j)), 256);
    for i = G-2:-1:3
        orig_col(i) = mod(col(i) - col(i-1) - col(i-2) - double(R(i,j)), 256);
    end
    orig_col(2) = mod(col(2) - col(1) - orig_col(G) - double(R(2,j)), 256);
    orig_col(1) = mod(col(1) - orig_col(G) - orig_col(G-1) - double(R(1,j)), 256);
    Q(:,j) = orig_col.';
end

% Then invert row diffusion.
for i = 1:M
    row = Q(i,:);
    G = N;
    orig_row = zeros(1, G);
    orig_row(G)   = mod(row(G)   - row(G-1) - row(G-2) - double(R(i,G)), 256);
    orig_row(G-1) = mod(row(G-1) - row(G-2) - row(G-3) - double(R(i,G-1)), 256);
    for j = G-2:-1:3
        orig_row(j) = mod(row(j) - row(j-1) - row(j-2) - double(R(i,j)), 256);
    end
    orig_row(2) = mod(row(2) - row(1) - orig_row(G) - double(R(i,2)), 256);
    orig_row(1) = mod(row(1) - orig_row(G) - orig_row(G-1) - double(R(i,1)), 256);
    Q(i,:) = orig_row;
end

P = uint8(Q);
end

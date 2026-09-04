function test_clsa_update_equivalence()
%TEST_CLSA_UPDATE_EQUIVALENCE Compare the new contraction with explicit N.

rng(15, 'twister');
partitions = {[2,3,4], [2,3,2,2]};

for p = 1:numel(partitions)
    n = partitions{p};
    X = cell(1, numel(n));
    for i = 1:numel(n)
        X{i} = randn(n(i),1);
    end
    V = randn(prod(n),1);

    for s = 1:numel(n)
        z_new = clsa_update_factor(n, s, V, X);
        z_ref = explicit_update(n, s, V, X);
        err = norm(z_new - z_ref);
        assert(err < 1e-10, 'General CLSA update mismatch: err=%g.', err);
    end
end
end

function z = explicit_update(n, s, V, X)
M = 1;
N = 1;
for i = 1:numel(n)
    if i ~= s
        xi = X{i}(:);
        M = M * (xi' * xi);
        N = kron(N, xi);
    else
        N = kron(N, eye(n(i)));
    end
end
z = (N' * V(:)) / M;
z = z(:);
end

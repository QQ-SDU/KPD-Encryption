function test_permutation_inverse()
%TEST_PERMUTATION_INVERSE Verify permutation invertibility.

rng(12, 'twister');
for shape = {[32,32], [24,32], [17,19]}
    sz = shape{1};
    P = uint8(randi([0,255], sz));
    S = rand(sz);
    T = permute_2d(P, S);
    R = inverse_permute_2d(T, S);
    assert(isequal(P, R), 'Permutation inverse failed for %dx%d.', sz(1), sz(2));
end
end

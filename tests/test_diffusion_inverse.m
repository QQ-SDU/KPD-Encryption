function test_diffusion_inverse()
%TEST_DIFFUSION_INVERSE Verify diffusion invertibility.

rng(13, 'twister');
for shape = {[32,32], [24,32], [17,19]}
    sz = shape{1};
    P = uint8(randi([0,255], sz));
    Rkey = uint8(randi([0,255], sz));
    C = diffuse_2d(P, Rkey);
    R = inverse_diffuse_2d(C, Rkey);
    assert(isequal(P, R), 'Diffusion inverse failed for %dx%d.', sz(1), sz(2));
end
end

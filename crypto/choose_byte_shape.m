function shape = choose_byte_shape(byte_len)
%CHOOSE_BYTE_SHAPE Choose a compact 2-D byte-block shape for encryption.
%
% Exact factorization is preferred. If unavailable, a near-square padded
% rectangle is returned. Both dimensions are at least 3 because the
% diffusion recurrence uses the previous two samples.

if byte_len < 1 || byte_len ~= floor(byte_len)
    error('choose_byte_shape:Length', 'byte_len must be a positive integer.');
end

root = floor(sqrt(byte_len));
for r = root:-1:3
    if mod(byte_len, r) == 0
        c = byte_len / r;
        if c >= 3
            shape = [r, c];
            return;
        end
    end
end

c = max(3, ceil(sqrt(byte_len)));
r = max(3, ceil(byte_len / c));
shape = [r, c];
end

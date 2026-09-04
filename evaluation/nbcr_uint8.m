function rate = nbcr_uint8(A, B)
%NBCR_UINT8 Bit-change rate (%) between equally sized uint8 arrays.

A = uint8(A(:));
B = uint8(B(:));
if numel(A) ~= numel(B)
    error('nbcr_uint8:Length', 'A and B must have identical lengths.');
end

D = bitxor(A, B);
persistent lut
if isempty(lut)
    lut = zeros(256, 1);
    for v = 0:255
        lut(v+1) = sum(bitget(uint8(v), 1:8));
    end
end
changed = sum(lut(double(D) + 1));
rate = changed / (8 * numel(D)) * 100;
end

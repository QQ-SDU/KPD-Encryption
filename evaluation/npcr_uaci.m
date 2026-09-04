function [npcr, uaci] = npcr_uaci(C1, C2)
%NPCR_UACI Compute NPCR (%) and UACI (%) for two equally sized byte arrays.

C1 = uint8(C1);
C2 = uint8(C2);
if ~isequal(size(C1), size(C2))
    error('npcr_uaci:Size', 'Inputs must have identical sizes.');
end

npcr = mean(C1(:) ~= C2(:)) * 100;
uaci = mean(abs(double(C1(:)) - double(C2(:))) / 255) * 100;
end

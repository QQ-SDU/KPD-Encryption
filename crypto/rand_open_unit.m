function x = rand_open_unit()
%RAND_OPEN_UNIT Draw a reproducible experiment value strictly inside (0,1).

x = rand();
epsv = 2^-52;
if x <= epsv
    x = epsv;
elseif x >= 1 - epsv
    x = 1 - epsv;
end
end

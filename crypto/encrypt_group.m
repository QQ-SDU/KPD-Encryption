function [cipher, key] = encrypt_group(param_vec, enc_cfg, key)
%ENCRYPT_GROUP Serialize and encrypt one KPD parameter group.

if nargin < 3 || isempty(key)
    key = make_group_key(enc_cfg.num_rounds, enc_cfg.a_max);
end

[block, serialization] = serialize_group(param_vec);
[M, N] = size(block);

rounds = key.num_rounds;
if numel(key.a) < rounds
    error('encrypt_group:KeyLength', 'key.a must contain one coefficient per round.');
end

P = block;
x = key.x0;
y = key.y0;
for r = 1:rounds
    theta_r = mod(key.theta * double(key.a(r)), 1);
    theta_r = clamp_open_unit(theta_r);
    [S, R, x, y] = lscm_generate(x, y, theta_r, M, N, enc_cfg.warmup);
    P = permute_2d(P, S);
    P = diffuse_2d(P, R);
end

cipher.bytes = P;
cipher.serialization = serialization;
cipher.num_rounds = rounds;
end

function x = clamp_open_unit(x)
if x <= 0
    x = 2^-52;
elseif x >= 1
    x = 1 - 2^-52;
end
end

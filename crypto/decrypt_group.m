function param_vec = decrypt_group(cipher, key, enc_cfg)
%DECRYPT_GROUP Decrypt and deserialize one encrypted KPD parameter group.

P = uint8(cipher.bytes);
[M, N] = size(P);
rounds = key.num_rounds;

S_cell = cell(rounds, 1);
R_cell = cell(rounds, 1);
x = key.x0;
y = key.y0;

for r = 1:rounds
    theta_r = mod(key.theta * double(key.a(r)), 1);
    theta_r = clamp_open_unit(theta_r);
    [S_cell{r}, R_cell{r}, x, y] = lscm_generate(x, y, theta_r, M, N, enc_cfg.warmup);
end

for r = rounds:-1:1
    P = inverse_diffuse_2d(P, R_cell{r});
    P = inverse_permute_2d(P, S_cell{r});
end

param_vec = deserialize_group(P, cipher.serialization);
end

function x = clamp_open_unit(x)
if x <= 0
    x = 2^-52;
elseif x >= 1
    x = 1 - 2^-52;
end
end

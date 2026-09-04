function test_encrypt_decrypt()
%TEST_ENCRYPT_DECRYPT Verify bit-exact group encryption/decryption.

project_root = fileparts(fileparts(mfilename('fullpath')));
cfg = default_config(project_root);
rng(14, 'twister');

for nparam = [96, 128, 137]
    x = randn(nparam, 1);
    key = make_group_key(cfg.encryption.num_rounds, cfg.encryption.a_max);
    [cipher, key] = encrypt_group(x, cfg.encryption, key);
    y = decrypt_group(cipher, key, cfg.encryption);
    assert(isequal(x, y), 'Encryption/decryption failed for %d parameters.', nparam);
end
end

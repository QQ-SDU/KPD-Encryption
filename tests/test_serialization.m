function test_serialization()
%TEST_SERIALIZATION Verify bit-exact double -> uint8 -> double recovery.

rng(11, 'twister');
for n = [96, 128, 137]
    x = randn(n, 1);
    [block, meta] = serialize_group(x);
    y = deserialize_group(block, meta);
    assert(isequal(x, y), 'Serialization round trip is not bit-exact.');
end
end

function param_vec = deserialize_group(block, meta)
%DESERIALIZE_GROUP Inverse of serialize_group with bit-exact double recovery.

bytes = uint8(block(:).');
if numel(bytes) < meta.byte_len
    error('deserialize_group:Length', 'Serialized block is shorter than meta.byte_len.');
end
bytes = bytes(1:meta.byte_len);

if mod(numel(bytes), 8) ~= 0
    error('deserialize_group:ByteCount', 'Double serialization requires a multiple of 8 bytes.');
end

param_vec = typecast(bytes, 'double');
param_vec = param_vec(:);

if numel(param_vec) ~= meta.param_len
    error('deserialize_group:ParamCount', 'Recovered parameter count does not match metadata.');
end
end

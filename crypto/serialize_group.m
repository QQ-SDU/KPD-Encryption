function [block, meta] = serialize_group(param_vec)
%SERIALIZE_GROUP Losslessly map double KPD parameters to a uint8 matrix.

param_vec = double(param_vec(:));
bytes = typecast(param_vec.', 'uint8');
byte_len = numel(bytes);
shape = choose_byte_shape(byte_len);
capacity = prod(shape);

padded = zeros(1, capacity, 'uint8');
padded(1:byte_len) = bytes;
block = reshape(padded, shape);

meta.param_len = numel(param_vec);
meta.byte_len = byte_len;
meta.shape = shape;
meta.padding_bytes = capacity - byte_len;
meta.value_class = 'double';
end

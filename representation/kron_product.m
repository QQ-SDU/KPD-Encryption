function r = kron_product(varargin)
%KRON_PRODUCT Kronecker product of an arbitrary number of vectors/matrices.

if nargin == 0
    error('kron_product:NoInput', 'At least one input is required.');
end

r = varargin{1};
for i = 2:nargin
    r = kron(r, varargin{i});
end
end

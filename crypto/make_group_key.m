function key = make_group_key(num_rounds, a_max)
%MAKE_GROUP_KEY Generate one independent experiment key for a parameter group.
%
% This function is intended for reproducible numerical experiments. It is
% not presented as a cryptographically secure random-number generator.

if nargin < 2 || isempty(a_max)
    a_max = 2^25 - 1;
end

key.x0 = rand_open_unit();
key.y0 = rand_open_unit();
key.theta = rand_open_unit();
key.num_rounds = double(num_rounds);
key.a = uint32(randi([1, a_max], 1, num_rounds));
end

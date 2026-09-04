function n = get_partition_for_image(image_size, cfg)
%GET_PARTITION_FOR_IMAGE Return the manuscript KPD partition for an image size.

h = image_size(1);
w = image_size(2);

if h == 256 && w == 256
    n = cfg.representation.partition_256;
elseif h == 512 && w == 512
    n = cfg.representation.partition_512;
else
    error('Unsupported image size %dx%d. Add an explicit KPD partition in the configuration.', h, w);
end

if prod(n) ~= h * w
    error('Invalid partition: prod(n) must equal the number of pixels in one channel.');
end
end

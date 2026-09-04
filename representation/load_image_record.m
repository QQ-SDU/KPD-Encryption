function [I, meta] = load_image_record(file_path)
%LOAD_IMAGE_RECORD Read an image without implicit resizing or grayscale conversion.

if exist(file_path, 'file') ~= 2
    error('load_image_record:NotFound', 'Cannot find image: %s', file_path);
end

I = imread(file_path);
info = imfinfo(file_path);

if ndims(I) == 2
    channels = 1;
    image_type = 'gray';
elseif ndims(I) == 3
    channels = size(I, 3);
    image_type = 'color';
else
    error('load_image_record:Dimensions', 'Unsupported image dimensionality.');
end

[~, name, ext] = fileparts(file_path);
meta.filename = [name, ext];
meta.file_path = file_path;
meta.height = size(I, 1);
meta.width = size(I, 2);
meta.channels = channels;
meta.image_type = image_type;
meta.matlab_class = class(I);
meta.bit_depth = info.BitDepth;
end

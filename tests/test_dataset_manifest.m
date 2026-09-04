function test_dataset_manifest()
%TEST_DATASET_MANIFEST Verify dataset metadata and, when present, image files.

project_root = fileparts(fileparts(mfilename('fullpath')));
cfg = default_config(project_root);
T = readtable(cfg.data.manifest, 'TextType', 'string');

assert(height(T) == 20, 'Expected 20 USC-SIPI manifest entries.');
assert(sum(T.width == 256 & T.height == 256 & T.channels == 3) == 7);
assert(sum(T.width == 512 & T.height == 512 & T.channels == 3) == 5);
assert(sum(T.width == 256 & T.height == 256 & T.channels == 1) == 6);
assert(sum(T.width == 512 & T.height == 512 & T.channels == 1) == 2);

exists_mask = false(height(T),1);
for i = 1:height(T)
    f = fullfile(project_root, T.relative_path(i));
    exists_mask(i) = exist(f,'file') == 2;
end

if ~any(exists_mask)
    fprintf('[SKIP] USC-SIPI image files are not bundled. Run prepare_usc_sipi first for file-level validation.\n');
    return;
end

assert(all(exists_mask), ...
    'Only part of the USC-SIPI subset is present. Run prepare_usc_sipi to complete it.');

for i = 1:height(T)
    f = fullfile(project_root, T.relative_path(i));
    [I, meta] = load_image_record(f);
    assert(meta.width == T.width(i) && meta.height == T.height(i));
    assert(meta.channels == T.channels(i));
    assert(strcmp(class(I), 'uint8'), 'Expected uint8 TIFF data.');
    n = get_partition_for_image(size(I), cfg);
    assert(prod(n) == meta.width * meta.height);
end
end

function results = run_all_tests()
%RUN_ALL_TESTS Execute integrity tests required before paper experiments.

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(project_root);
setup_paths();

tests = { ...
    @test_serialization, ...
    @test_permutation_inverse, ...
    @test_diffusion_inverse, ...
    @test_encrypt_decrypt, ...
    @test_clsa_update_equivalence, ...
    @test_dataset_manifest ...
};

names = cellfun(@func2str, tests, 'UniformOutput', false);
passed = false(numel(tests),1);
message = strings(numel(tests),1);

fprintf('=== KPD-Encryption: unit tests ===\n');
for i = 1:numel(tests)
    try
        tests{i}();
        passed(i) = true;
        message(i) = "PASS";
        fprintf('[PASS] %s\n', names{i});
    catch ME
        message(i) = string(ME.message);
        fprintf('[FAIL] %s: %s\n', names{i}, ME.message);
    end
end

results = table(string(names(:)), passed, message, ...
    'VariableNames', {'Test','Passed','Message'});

if ~all(passed)
    error('run_all_tests:Failure', 'At least one unit test failed. Do not run paper experiments yet.');
end
fprintf('All %d tests passed.\n', numel(tests));
end

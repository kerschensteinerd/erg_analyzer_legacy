function cacheDir = getErgAnalyzerCacheDir()
% getErgAnalyzerCacheDir Return the writable per-user cache folder.

cacheDir = fullfile(prefdir, 'ERGAnalyzer', 'cache');
end

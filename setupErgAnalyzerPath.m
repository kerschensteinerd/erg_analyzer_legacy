function setupErgAnalyzerPath()
% setupErgAnalyzerPath Add the ERG Analyzer source folders to the MATLAB path.

rootDir = getErgAnalyzerRoot();
addpath(rootDir);
addpath(fullfile(rootDir, 'app'));
addpath(fullfile(rootDir, 'analysis'));
addpath(fullfile(rootDir, 'import'));
addpath(fullfile(rootDir, 'export'));

packagingDir = fullfile(rootDir, 'packaging');
if isfolder(packagingDir)
    addpath(packagingDir);
end
end

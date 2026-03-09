function rootDir = getErgAnalyzerRoot()
% getErgAnalyzerRoot Resolve the project root in MATLAB and deployed builds.

persistent cachedRoot

if ~isempty(cachedRoot) && isfolder(cachedRoot)
    rootDir = cachedRoot;
    return;
end

candidates = {};
if isdeployed
    candidates = [candidates, {ctfroot, fileparts(ctfroot), pwd}];
else
    candidates = [candidates, {fileparts(mfilename('fullpath')), pwd}];
end

for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if localLooksLikeRoot(candidate)
        cachedRoot = candidate;
        rootDir = candidate;
        return;
    end
end

rootDir = fileparts(mfilename('fullpath'));
cachedRoot = rootDir;
end

function tf = localLooksLikeRoot(candidate)
tf = isfolder(candidate) && ...
    isfolder(fullfile(candidate, 'app')) && ...
    isfolder(fullfile(candidate, 'analysis')) && ...
    isfolder(fullfile(candidate, 'import')) && ...
    isfolder(fullfile(candidate, 'export'));
end

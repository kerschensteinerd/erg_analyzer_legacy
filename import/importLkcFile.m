function [session, importInfo] = importLkcFile(filePath, varargin)
% importLkcFile Dispatch import based on file extension.

if isstring(filePath)
    filePath = char(filePath);
end

if ~ischar(filePath) || isempty(filePath)
    error("ERG:InvalidImportPath", "Import path must be a character vector or string scalar.");
end

logFcn = localResolveLogFcn(varargin{:});
overallTimer = tic;

[~, ~, ext] = fileparts(filePath);
ext = lower(ext);

switch ext
    case ".mdb"
        [session, importInfo] = localImportMdbWithCache(filePath, logFcn);
    case ".mat"
        loadTimer = tic;
        session = loadSessionMat(filePath);
        importInfo = struct( ...
            "SourceType", "MAT", ...
            "UsedCache", false, ...
            "CacheStatus", "not_applicable", ...
            "CacheFile", "", ...
            "LoadSeconds", toc(loadTimer), ...
            "ComputeSeconds", 0, ...
            "TotalSeconds", 0);

        if ~localHasComputedResults(session)
            computeTimer = tic;
            session = computeSessionResults(session);
            importInfo.ComputeSeconds = toc(computeTimer);
            localLog(logFcn, sprintf('Computed session results in %.2f s.', importInfo.ComputeSeconds));
        end
    otherwise
        error("ERG:UnsupportedFile", ...
            "Unsupported file type '%s'. Expected .mdb or .mat.", ext);
end

importInfo.TotalSeconds = toc(overallTimer);
end

function [session, importInfo] = localImportMdbWithCache(filePath, logFcn)
sourceInfo = dir(filePath);
cacheInfo = localBuildCacheInfo(filePath, sourceInfo);
cacheLoad = localTryLoadCache(cacheInfo);

if cacheLoad.IsHit
    session = cacheLoad.Session;
    session.sourceFile = filePath;
    session.importedAt = datetime("now");
    if ~isfield(session, "analysisSettings") || ~isstruct(session.analysisSettings)
        session.analysisSettings = struct();
    end
    session.analysisSettings.cacheStatus = "hit";
    session.analysisSettings.cacheFile = cacheInfo.CacheFile;

    importInfo = struct( ...
        "SourceType", "MDB", ...
        "UsedCache", true, ...
        "CacheStatus", "hit", ...
        "CacheFile", string(cacheInfo.CacheFile), ...
        "LoadSeconds", cacheLoad.LoadSeconds, ...
        "ComputeSeconds", 0, ...
        "TotalSeconds", 0);
    localLog(logFcn, sprintf('Using cached session (%.2f s).', cacheLoad.LoadSeconds));
    return;
end

if cacheLoad.ShouldReportMiss
    localLog(logFcn, sprintf('Rebuilding cache because %s.', cacheLoad.Reason));
else
    localLog(logFcn, 'Importing MDB directly.');
end

importTimer = tic;
[session, mdbInfo] = importLkcMdb(filePath, logFcn);
directImportSeconds = toc(importTimer);

computeTimer = tic;
session = computeSessionResults(session);
computeSeconds = toc(computeTimer);
localLog(logFcn, sprintf('Computed session results in %.2f s.', computeSeconds));

if ~isfield(session, "analysisSettings") || ~isstruct(session.analysisSettings)
    session.analysisSettings = struct();
end
session.analysisSettings.cacheStatus = "rebuilt";
session.analysisSettings.cacheFile = cacheInfo.CacheFile;
session.analysisSettings.importTimings = mdbInfo;

localTrySaveCache(cacheInfo, session);

importInfo = struct( ...
    "SourceType", "MDB", ...
    "UsedCache", false, ...
    "CacheStatus", cacheLoad.CacheStatus, ...
    "CacheFile", string(cacheInfo.CacheFile), ...
    "LoadSeconds", directImportSeconds, ...
    "ComputeSeconds", computeSeconds, ...
    "TotalSeconds", 0);
end

function tf = localHasComputedResults(session)
tf = isfield(session, "results") && isstruct(session.results) && ...
    (isfield(session.results, "rawTable") || isfield(session.results, "summaryTable"));
end

function logFcn = localResolveLogFcn(varargin)
logFcn = [];
if isempty(varargin)
    return;
end

candidate = varargin{1};
if isa(candidate, 'function_handle')
    logFcn = candidate;
end
end

function localLog(logFcn, message)
if isempty(logFcn)
    return;
end

logFcn(string(message));
end

function cacheInfo = localBuildCacheInfo(filePath, sourceInfo)
cacheDir = getErgAnalyzerCacheDir();
if ~isfolder(cacheDir)
    mkdir(cacheDir);
end

cacheId = localCacheId(filePath);
cacheInfo = struct( ...
    "CacheDir", cacheDir, ...
    "CacheFile", fullfile(cacheDir, [cacheId '.mat']), ...
    "SourceFile", string(filePath), ...
    "SourceBytes", sourceInfo.bytes, ...
    "SourceModified", sourceInfo.datenum, ...
    "AppVersion", getErgAnalyzerVersion(), ...
    "MATLABRelease", string(version('-release')));
end

function cacheId = localCacheId(filePath)
seed = char(string(filePath));

if usejava('jvm')
    try
        md = java.security.MessageDigest.getInstance('MD5');
        md.update(uint8(seed));
        hashBytes = uint8(md.digest());
        cacheId = lower(reshape(dec2hex(hashBytes, 2).', 1, []));
        return;
    catch
    end
end

bytes = uint64(uint8(seed));
weights = uint64(1:numel(bytes));
checksum = sum(bytes .* weights);
cacheId = char(matlab.lang.makeValidName(sprintf('cache_%016x', checksum)));
end

function cacheLoad = localTryLoadCache(cacheInfo)
cacheLoad = struct( ...
    "IsHit", false, ...
    "ShouldReportMiss", false, ...
    "Reason", "", ...
    "CacheStatus", "miss", ...
    "LoadSeconds", 0, ...
    "Session", struct());

if ~isfile(cacheInfo.CacheFile)
    return;
end

loadTimer = tic;
try
    loaded = load(cacheInfo.CacheFile, 'session', 'metadata');
catch
    cacheLoad.ShouldReportMiss = true;
    cacheLoad.Reason = "the cached session could not be read";
    cacheLoad.CacheStatus = "invalid";
    return;
end
cacheLoad.LoadSeconds = toc(loadTimer);

if ~isfield(loaded, 'session') || ~isfield(loaded, 'metadata')
    cacheLoad.ShouldReportMiss = true;
    cacheLoad.Reason = "the cached session was incomplete";
    cacheLoad.CacheStatus = "invalid";
    return;
end

metadata = loaded.metadata;
if ~localCacheMatches(metadata, cacheInfo)
    cacheLoad.ShouldReportMiss = true;
    cacheLoad.Reason = "source or app metadata changed";
    cacheLoad.CacheStatus = "stale";
    return;
end

if ~localHasComputedResults(loaded.session)
    cacheLoad.ShouldReportMiss = true;
    cacheLoad.Reason = "the cached session did not contain computed results";
    cacheLoad.CacheStatus = "invalid";
    return;
end

cacheLoad.IsHit = true;
cacheLoad.CacheStatus = "hit";
cacheLoad.Session = loaded.session;
end

function tf = localCacheMatches(metadata, cacheInfo)
requiredFields = ["SourceFile", "SourceBytes", "SourceModified", "AppVersion", "MATLABRelease"];
for idx = 1:numel(requiredFields)
    if ~isfield(metadata, requiredFields(idx))
        tf = false;
        return;
    end
end

tf = string(metadata.SourceFile) == cacheInfo.SourceFile && ...
    double(metadata.SourceBytes) == double(cacheInfo.SourceBytes) && ...
    abs(double(metadata.SourceModified) - double(cacheInfo.SourceModified)) < 1e-12 && ...
    string(metadata.AppVersion) == cacheInfo.AppVersion && ...
    string(metadata.MATLABRelease) == cacheInfo.MATLABRelease;
end

function localTrySaveCache(cacheInfo, session)
metadata = struct( ...
    "SourceFile", cacheInfo.SourceFile, ...
    "SourceBytes", cacheInfo.SourceBytes, ...
    "SourceModified", cacheInfo.SourceModified, ...
    "AppVersion", cacheInfo.AppVersion, ...
    "MATLABRelease", cacheInfo.MATLABRelease);

try
    save(cacheInfo.CacheFile, 'session', 'metadata', '-mat');
catch
end
end

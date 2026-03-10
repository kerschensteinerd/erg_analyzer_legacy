function versionText = getErgAnalyzerVersion()
% getErgAnalyzerVersion Return the current ERG Analyzer app version.

persistent cachedVersion

if isempty(cachedVersion)
    cachedVersion = "";
elseif ischar(cachedVersion)
    cachedVersion = string(cachedVersion);
end

if strlength(cachedVersion) > 0
    versionText = cachedVersion;
    return;
end

versionFile = fullfile(getErgAnalyzerRoot(), 'VERSION');
if isfile(versionFile)
    try
        cachedVersion = strtrim(string(fileread(versionFile)));
    catch
        cachedVersion = "0.0.0";
    end
else
    cachedVersion = "0.0.0";
end

if strlength(cachedVersion) == 0
    cachedVersion = "0.0.0";
end

versionText = cachedVersion;
end

function buildInfo = buildRelease(varargin)
% buildRelease Build a standalone ERG Analyzer release for the current platform.

opts = localParseInputs(varargin{:});
rootDir = getErgAnalyzerRoot();
versionText = localReadVersion(rootDir, opts.Version);
platformTag = localPlatformTag();

localAssertCompiler();

outputRoot = fullfile(rootDir, 'dist', versionText, platformTag);
standaloneDir = fullfile(outputRoot, 'standalone');
installerDir = fullfile(outputRoot, 'installer');

if ~isfolder(outputRoot)
    mkdir(outputRoot);
end
if ~isfolder(standaloneDir)
    mkdir(standaloneDir);
end
if ~isfolder(installerDir)
    mkdir(installerDir);
end

appFile = fullfile(rootDir, 'launchERGAnalyzer.m');
additionalFiles = localAdditionalFiles(rootDir);

results = compiler.build.standaloneApplication(appFile, ...
    'ExecutableName', 'ERGAnalyzer', ...
    'ExecutableVersion', localExecutableVersion(versionText), ...
    'OutputDir', standaloneDir, ...
    'AdditionalFiles', additionalFiles, ...
    'AutoDetectDataFiles', false, ...
    'Verbose', true);

standaloneZip = fullfile(outputRoot, sprintf('ERGAnalyzer-%s-%s-standalone.zip', versionText, platformTag));
localZipBuildFolder(standaloneDir, standaloneZip);

installerZip = "";
if opts.CreateInstaller
    installerName = sprintf('ERGAnalyzer-%s-%s-installer', versionText, platformTag);
    installationNotes = fileread(fullfile(rootDir, 'docs', 'INSTALL.md'));

    compiler.package.installer(results, ...
        'ApplicationName', 'ERG Analyzer', ...
        'AuthorName', opts.AuthorName, ...
        'AuthorCompany', opts.AuthorCompany, ...
        'Summary', 'Legacy LKC ERG analysis desktop app', ...
        'Description', 'Cross-platform desktop application for importing and analyzing legacy LKC ERG MDB files.', ...
        'InstallationNotes', installationNotes, ...
        'InstallerName', installerName, ...
        'OutputDir', installerDir, ...
        'RuntimeDelivery', opts.RuntimeDelivery, ...
        'Version', versionText, ...
        'AdditionalFiles', { ...
            fullfile(rootDir, 'docs', 'INSTALL.md'), ...
            fullfile(rootDir, 'IMPORTER_REQUIREMENTS.md')}, ...
        'Verbose', true);

    installerZip = fullfile(outputRoot, sprintf('ERGAnalyzer-%s-%s-installer.zip', versionText, platformTag));
    localZipBuildFolder(installerDir, installerZip);
end

buildInfo = struct();
buildInfo.Version = versionText;
buildInfo.Platform = platformTag;
buildInfo.RootDir = rootDir;
buildInfo.StandaloneDir = standaloneDir;
buildInfo.InstallerDir = installerDir;
buildInfo.StandaloneZip = standaloneZip;
buildInfo.InstallerZip = installerZip;
buildInfo.MATLABRelease = version('-release');
buildInfo.RuntimeDelivery = char(opts.RuntimeDelivery);
buildInfo.BuildTime = datetime('now');

localWriteBuildInfo(outputRoot, buildInfo);

fprintf('Release build complete.\n');
fprintf('Standalone ZIP: %s\n', standaloneZip);
if strlength(installerZip) > 0
    fprintf('Installer ZIP: %s\n', installerZip);
end
end

function opts = localParseInputs(varargin)
parser = inputParser;
parser.addParameter('Version', "", @(x) ischar(x) || isstring(x));
parser.addParameter('RuntimeDelivery', "web", @(x) any(strcmp(string(x), ["web", "installer", "none"])));
parser.addParameter('CreateInstaller', true, @(x) islogical(x) || isnumeric(x));
parser.addParameter('AuthorName', "Kerschensteiner Lab", @(x) ischar(x) || isstring(x));
parser.addParameter('AuthorCompany', "Kerschensteiner Lab", @(x) ischar(x) || isstring(x));
parser.parse(varargin{:});
opts = parser.Results;
opts.RuntimeDelivery = string(opts.RuntimeDelivery);
end

function localAssertCompiler()
if isempty(ver('compiler')) || ~license('test', 'Compiler')
    error('ERG:CompilerUnavailable', ...
        ['MATLAB Compiler is required to build a standalone release. ' ...
         'Run checkCompilerSetup() to verify this machine.']);
end
if isempty(which('compiler.package.installer'))
    error('ERG:InstallerUnavailable', ...
        ['compiler.package.installer is not available in this MATLAB release. ' ...
         'Use a release with MATLAB Compiler installer packaging support.']);
end
end

function versionText = localReadVersion(rootDir, requestedVersion)
requestedVersion = string(requestedVersion);
if strlength(strtrim(requestedVersion)) > 0
    versionText = char(strtrim(requestedVersion));
    return;
end

versionFile = fullfile(rootDir, 'VERSION');
if isfile(versionFile)
    versionText = strtrim(fileread(versionFile));
else
    versionText = '0.1.0';
end
end

function additionalFiles = localAdditionalFiles(rootDir)
additionalFiles = { ...
    fullfile(rootDir, 'app'), ...
    fullfile(rootDir, 'analysis'), ...
    fullfile(rootDir, 'import'), ...
    fullfile(rootDir, 'export'), ...
    fullfile(rootDir, 'third_party', 'ucanaccess'), ...
    fullfile(rootDir, 'getErgAnalyzerRoot.m'), ...
    fullfile(rootDir, 'IMPORTER_REQUIREMENTS.md')};
end

function platformTag = localPlatformTag()
if ismac
    platformTag = 'macOS';
elseif ispc
    platformTag = 'Windows';
else
    platformTag = char(string(computer));
end
end

function versionOut = localExecutableVersion(versionText)
parts = split(string(versionText), '.');
parts(end + 1:4) = "0";
versionOut = char(strjoin(parts(1:4), '.'));
end

function localZipBuildFolder(sourceDir, zipPath)
if isfile(zipPath)
    delete(zipPath);
end

listing = dir(sourceDir);
entryNames = {};
for idx = 1:numel(listing)
    if any(strcmp(listing(idx).name, {'.', '..'}))
        continue;
    end
    entryNames{end + 1} = fullfile(sourceDir, listing(idx).name); %#ok<AGROW>
end

if isempty(entryNames)
    error('ERG:EmptyBuildOutput', 'No build output found in %s', sourceDir);
end

zip(zipPath, entryNames, sourceDir);
end

function localWriteBuildInfo(outputRoot, buildInfo)
lines = { ...
    sprintf('Version: %s', buildInfo.Version), ...
    sprintf('Platform: %s', buildInfo.Platform), ...
    sprintf('MATLAB release: %s', buildInfo.MATLABRelease), ...
    sprintf('Runtime delivery: %s', buildInfo.RuntimeDelivery), ...
    sprintf('Build time: %s', char(string(buildInfo.BuildTime))), ...
    sprintf('Standalone ZIP: %s', buildInfo.StandaloneZip), ...
    sprintf('Installer ZIP: %s', buildInfo.InstallerZip)};

fid = fopen(fullfile(outputRoot, 'BUILD_INFO.txt'), 'w');
cleanupObj = onCleanup(@() fclose(fid));
for idx = 1:numel(lines)
    fprintf(fid, '%s\n', lines{idx});
end
clear cleanupObj
end

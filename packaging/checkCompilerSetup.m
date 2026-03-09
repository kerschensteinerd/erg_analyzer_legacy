function info = checkCompilerSetup()
% checkCompilerSetup Report whether this machine can build a standalone release.

rootDir = getErgAnalyzerRoot();
compilerInfo = ver('compiler');

info = struct();
info.RootDir = rootDir;
info.MATLABVersion = version;
info.MATLABRelease = version('-release');
info.CompilerInstalled = ~isempty(compilerInfo);
info.CompilerAvailable = localHasCompilerLicense();
info.PackageInstallerAvailable = ~isempty(which('compiler.package.installer'));
info.RuntimeDownloadAvailable = ~isempty(which('compiler.runtime.download'));
info.MdbImportSetup = checkMdbImportSetup();

fprintf('ERG Analyzer packaging setup\n');
fprintf('Root: %s\n', rootDir);
fprintf('MATLAB: %s (%s)\n', info.MATLABVersion, info.MATLABRelease);
fprintf('MATLAB Compiler installed: %d\n', info.CompilerInstalled);
fprintf('MATLAB Compiler licensed: %d\n', info.CompilerAvailable);
fprintf('Installer packaging available: %d\n', info.PackageInstallerAvailable);
fprintf('Runtime download helper available: %d\n', info.RuntimeDownloadAvailable);
end

function tf = localHasCompilerLicense()
tf = false;
try
    tf = license('test', 'Compiler');
catch
    tf = false;
end
end

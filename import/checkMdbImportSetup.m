function info = checkMdbImportSetup()
% checkMdbImportSetup Report which MDB import providers are available in MATLAB.

info = struct();
info.IsWindows = ispc;
info.HasJvm = usejava('jvm');
info.JavaVersion = localJavaDescription();
info.UCanAccessJars = localFindUcanaccessJars();
info.HasUCanAccessJars = ~isempty(info.UCanAccessJars);
info.CanLoadUCanAccessDriver = false;

if info.HasUCanAccessJars && info.HasJvm
    info.CanLoadUCanAccessDriver = localCanLoadUcanaccessDriver(info.UCanAccessJars);
end

fprintf('MDB import setup\n');
fprintf('Platform: %s\n', computer);
fprintf('Java: %s\n\n', info.JavaVersion);

if info.IsWindows
    fprintf('Windows ADO/OLEDB path: potentially available if Access Database Engine is installed.\n');
else
    fprintf('Windows ADO/OLEDB path: not available on this platform.\n');
end

if info.HasUCanAccessJars
    fprintf('\nUCanAccess jar path found:\n');
    for idx = 1:numel(info.UCanAccessJars)
        fprintf('  %s\n', info.UCanAccessJars{idx});
    end
    fprintf('UCanAccess driver loadable: %d\n', info.CanLoadUCanAccessDriver);
else
    fprintf('\nNo UCanAccess jars found.\n');
    fprintf('Expected one of these locations:\n');
    fprintf('  %s\n', fullfile(getErgAnalyzerRoot(), 'third_party', 'ucanaccess'));
    fprintf('  %s\n', fullfile(getErgAnalyzerRoot(), 'lib', 'ucanaccess'));
    fprintf('  UCANACCESS_HOME environment variable\n');
end
end

function jarPaths = localFindUcanaccessJars()
rootDir = getErgAnalyzerRoot();
candidateRoots = { ...
    fullfile(rootDir, 'third_party', 'ucanaccess'), ...
    fullfile(rootDir, 'lib', 'ucanaccess')};

envRoot = getenv('UCANACCESS_HOME');
if ~isempty(envRoot)
    candidateRoots{end + 1} = envRoot; %#ok<AGROW>
end

jarPaths = {};
for idx = 1:numel(candidateRoots)
    root = candidateRoots{idx};
    if ~isfolder(root)
        continue;
    end

    directJars = dir(fullfile(root, '*.jar'));
    libJars = dir(fullfile(root, 'lib', '*.jar'));
    jars = [directJars; libJars]; %#ok<AGROW>
    for jarIdx = 1:numel(jars)
        jarPaths{end + 1} = fullfile(jars(jarIdx).folder, jars(jarIdx).name); %#ok<AGROW>
    end

    if ~isempty(jarPaths)
        jarPaths = unique(jarPaths, 'stable');
        return;
    end
end
end

function desc = localJavaDescription()
if ~usejava('jvm')
    desc = 'JVM not available';
    return;
end

desc = 'JVM available';
try
    v = char(java.lang.System.getProperty('java.version'));
    if ~isempty(v)
        desc = ['JVM available (Java ' v ')'];
    end
catch
end
end

function tf = localCanLoadUcanaccessDriver(jarPaths)
tf = false;

dynamicPath = string(javaclasspath('-dynamic'));
for idx = 1:numel(jarPaths)
    if ~any(dynamicPath == string(jarPaths{idx}))
        javaaddpath(jarPaths{idx});
    end
end

try
    driver = javaObject('net.ucanaccess.jdbc.UcanaccessDriver'); %#ok<NASGU>
    tf = true;
catch
    tf = false;
end
end

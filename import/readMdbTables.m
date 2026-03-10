function mdbData = readMdbTables(filePath, mode)
% readMdbTables Read user tables from an Access MDB using the first available provider.

if nargin < 2 || strlength(string(mode)) == 0
    mode = "full";
end
mode = localNormalizeMode(mode);

providers = {@localReadViaAdo, @localReadViaJdbc};
lastError = [];

for idx = 1:numel(providers)
    try
        mdbData = providers{idx}(filePath, mode);
        return;
    catch err
        lastError = err;
    end
end

msg = sprintf([ ...
    'Could not open MDB file ''%s''.\n\n' ...
    'Supported import paths:\n' ...
    '1. Windows MATLAB with Microsoft Access Database Engine installed (ADO/OLEDB)\n' ...
    '2. Any platform with UCanAccess jars available under third_party/ucanaccess or UCANACCESS_HOME\n\n' ...
    'Last provider error:\n%s'], filePath, localErrorMessage(lastError));
error("ERG:NoMdbProvider", "%s", msg);
end

function mode = localNormalizeMode(mode)
mode = lower(string(mode));
if mode ~= "full" && mode ~= "import"
    error("ERG:InvalidReadMode", "Unsupported MDB read mode '%s'.", char(mode));
end
end

function mdbData = localReadViaAdo(filePath, mode)
if ~ispc
    error("ERG:AdoNotAvailable", "ADO import is only available on Windows MATLAB.");
end

conn = [];
providerNames = { ...
    'Microsoft.ACE.OLEDB.16.0', ...
    'Microsoft.ACE.OLEDB.12.0', ...
    'Microsoft.Jet.OLEDB.4.0'};
providerUsed = '';
openErrors = strings(0, 1);

for idx = 1:numel(providerNames)
    provider = providerNames{idx};
    conn = actxserver('ADODB.Connection');
    try
        conn.Open(sprintf('Provider=%s;Data Source=%s;Persist Security Info=False;', provider, filePath));
        providerUsed = provider;
        break;
    catch err
        openErrors(end + 1, 1) = provider + ": " + string(err.message); %#ok<AGROW>
        try
            conn.Close;
        catch
        end
        conn = [];
    end
end

if isempty(conn)
    error("ERG:AdoConnectionFailed", "%s", strjoin(cellstr(openErrors), newline));
end

cleanup = onCleanup(@() localSafeCloseAdoConnection(conn));
schemas = localGetAdoSchemas(conn);
selectedTableNames = localSelectTableNamesForMode(schemas, mode);
tables = repmat(struct("Name", "", "Data", table()), 1, numel(selectedTableNames));

for idx = 1:numel(selectedTableNames)
    tables(idx).Name = selectedTableNames{idx};
    tables(idx).Data = localAdoQueryTable(conn, selectedTableNames{idx});
end

mdbData = struct();
mdbData.Provider = providerUsed;
mdbData.Mode = mode;
mdbData.TableNames = string(selectedTableNames(:));
mdbData.AvailableTableNames = string({schemas.Name}');
mdbData.Schemas = schemas;
mdbData.Tables = tables;

clear cleanup
localSafeCloseAdoConnection(conn);
end

function schemas = localGetAdoSchemas(conn)
schemaRs = conn.OpenSchema(20);
cleanup = onCleanup(@() localSafeCloseRecordset(schemaRs));
schemas = repmat(struct("Name", "", "Type", "", "Columns", strings(0, 1)), 0, 1);

while ~schemaRs.EOF
    tableName = string(schemaRs.Fields.Item('TABLE_NAME').Value);
    tableType = string(schemaRs.Fields.Item('TABLE_TYPE').Value);

    if any(tableType == ["TABLE", "VIEW"]) && ~startsWith(tableName, "MSys")
        cols = localGetAdoTableColumns(conn, char(tableName));
        schemas(end + 1, 1) = struct( ... %#ok<AGROW>
            "Name", char(tableName), ...
            "Type", char(tableType), ...
            "Columns", cols(:));
    end
    schemaRs.MoveNext;
end

clear cleanup
localSafeCloseRecordset(schemaRs);
end

function columns = localGetAdoTableColumns(conn, tableName)
columns = strings(0, 1);
query = sprintf('SELECT * FROM [%s] WHERE 1=0', strrep(tableName, ']', ']]'));

try
    rs = conn.Execute(query);
catch
    query = sprintf('SELECT TOP 1 * FROM [%s]', strrep(tableName, ']', ']]'));
    rs = conn.Execute(query);
end

cleanup = onCleanup(@() localSafeCloseRecordset(rs));
fieldCount = rs.Fields.Count;
for idx = 1:fieldCount
    columns(end + 1, 1) = string(rs.Fields.Item(idx - 1).Name); %#ok<AGROW>
end

clear cleanup
localSafeCloseRecordset(rs);
end

function tbl = localAdoQueryTable(conn, tableName)
query = sprintf('SELECT * FROM [%s]', strrep(tableName, ']', ']]'));
rs = conn.Execute(query);
cleanup = onCleanup(@() localSafeCloseRecordset(rs));

fieldCount = rs.Fields.Count;
originalNames = cell(1, fieldCount);
validNames = cell(1, fieldCount);

for idx = 1:fieldCount
    fieldName = char(rs.Fields.Item(idx - 1).Name);
    originalNames{idx} = fieldName;
    validNames{idx} = matlab.lang.makeValidName(fieldName, 'ReplacementStyle', 'delete');
end

validNames = matlab.lang.makeUniqueStrings(validNames);
rows = cell(0, fieldCount);

while ~rs.EOF
    row = cell(1, fieldCount);
    for idx = 1:fieldCount
        row{idx} = localConvertAdoValue(rs.Fields.Item(idx - 1).Value);
    end
    rows(end + 1, :) = row; %#ok<AGROW>
    rs.MoveNext;
end

tbl = cell2table(rows, 'VariableNames', validNames);
tbl.Properties.UserData.OriginalVariableNames = originalNames;

clear cleanup
localSafeCloseRecordset(rs);
end

function value = localConvertAdoValue(rawValue)
value = [];

if isempty(rawValue)
    return;
end

if ischar(rawValue) || isnumeric(rawValue) || islogical(rawValue) || isdatetime(rawValue)
    value = rawValue;
    return;
end

className = class(rawValue);

if strcmp(className, 'System.String')
    value = char(rawValue);
    return;
end

if contains(className, 'Date')
    try
        millis = double(rawValue.getTime());
        value = datetime(millis / 1000, 'ConvertFrom', 'posixtime');
        return;
    catch
    end
end

if contains(className, 'Double') || contains(className, 'Integer') || contains(className, 'Long')
    try
        value = double(rawValue);
        return;
    catch
    end
end

try
    value = char(string(rawValue));
catch
    value = rawValue;
end
end

function mdbData = localReadViaJdbc(filePath, mode)
jarPaths = localResolveUcanaccessJars();
if isempty(jarPaths)
    error("ERG:JdbcUnavailable", "UCanAccess jars not found.");
end

driver = localGetJdbcDriver(jarPaths);
mirrorRoot = localEnsureMirrorRoot();
existingMirrorDirs = localListMirrorDirs(mirrorRoot);
url = ['jdbc:ucanaccess://' filePath ...
    ';memory=false' ...
    ';mirrorFolder=' localJdbcPath(mirrorRoot)];
props = java.util.Properties();
conn = driver.connect(url, props);
if isempty(conn)
    error("ERG:JdbcConnectionFailed", ...
        "UCanAccess driver loaded, but could not open URL: %s", url);
end
cleanup = onCleanup(@() localSafeCloseJdbcConnection(conn));
cleanupMirror = onCleanup(@() localCleanupMirrorDirs(mirrorRoot, existingMirrorDirs));

meta = conn.getMetaData();
schemas = localGetJdbcSchemas(meta);
selectedTableNames = localSelectTableNamesForMode(schemas, mode);
tables = repmat(struct("Name", "", "Data", table()), 1, numel(selectedTableNames));

for idx = 1:numel(selectedTableNames)
    tables(idx).Name = selectedTableNames{idx};
    tables(idx).Data = localJdbcQueryTable(conn, selectedTableNames{idx});
end

mdbData = struct();
mdbData.Provider = "UCanAccess";
mdbData.Mode = mode;
mdbData.TableNames = string(selectedTableNames(:));
mdbData.AvailableTableNames = string({schemas.Name}');
mdbData.Schemas = schemas;
mdbData.Tables = tables;

clear cleanup cleanupMirror
localSafeCloseJdbcConnection(conn);
localCleanupMirrorDirs(mirrorRoot, existingMirrorDirs);
end

function driver = localGetJdbcDriver(jarPaths)
persistent cachedDriver

dynamicPath = string(javaclasspath('-dynamic'));
for idx = 1:numel(jarPaths)
    if ~any(dynamicPath == string(jarPaths{idx}))
        javaaddpath(jarPaths{idx});
    end
end

if ~isempty(cachedDriver)
    try
        cachedDriver.getMajorVersion();
        driver = cachedDriver;
        return;
    catch
        cachedDriver = [];
    end
end

try
    cachedDriver = javaObject('net.ucanaccess.jdbc.UcanaccessDriver');
catch err
    error("ERG:JdbcDriverLoadFailed", ...
        "UCanAccess jar was found, but MATLAB could not load the driver class: %s", err.message);
end

driver = cachedDriver;
end

function schemas = localGetJdbcSchemas(meta)
rs = meta.getTables([], [], '%', []);
cleanup = onCleanup(@() localSafeCloseJdbcResult(rs));
schemas = repmat(struct("Name", "", "Type", "", "Columns", strings(0, 1)), 0, 1);

while rs.next()
    tableName = char(rs.getString('TABLE_NAME'));
    tableType = char(rs.getString('TABLE_TYPE'));
    if any(strcmpi(tableType, {'TABLE', 'VIEW'})) && ~startsWith(string(tableName), "MSys")
        schemas(end + 1, 1) = struct( ... %#ok<AGROW>
            "Name", tableName, ...
            "Type", tableType, ...
            "Columns", localGetJdbcTableColumns(meta, tableName));
    end
end

clear cleanup
localSafeCloseJdbcResult(rs);
end

function columns = localGetJdbcTableColumns(meta, tableName)
columns = strings(0, 1);
rs = meta.getColumns([], [], tableName, '%');
cleanup = onCleanup(@() localSafeCloseJdbcResult(rs));

while rs.next()
    columns(end + 1, 1) = string(char(rs.getString('COLUMN_NAME'))); %#ok<AGROW>
end

clear cleanup
localSafeCloseJdbcResult(rs);
end

function tbl = localJdbcQueryTable(conn, tableName)
stmt = conn.createStatement();
cleanupStmt = onCleanup(@() localSafeCloseJdbcStatement(stmt));
rs = stmt.executeQuery(sprintf('SELECT * FROM [%s]', strrep(tableName, ']', ']]')));
cleanupRs = onCleanup(@() localSafeCloseJdbcResult(rs));

md = rs.getMetaData();
fieldCount = md.getColumnCount();
originalNames = cell(1, fieldCount);
validNames = cell(1, fieldCount);

for idx = 1:fieldCount
    fieldName = char(md.getColumnLabel(idx));
    originalNames{idx} = fieldName;
    validNames{idx} = matlab.lang.makeValidName(fieldName, 'ReplacementStyle', 'delete');
end
validNames = matlab.lang.makeUniqueStrings(validNames);

rows = cell(0, fieldCount);
while rs.next()
    row = cell(1, fieldCount);
    for idx = 1:fieldCount
        row{idx} = localConvertJavaValue(rs.getObject(idx));
    end
    rows(end + 1, :) = row; %#ok<AGROW>
end

tbl = cell2table(rows, 'VariableNames', validNames);
tbl.Properties.UserData.OriginalVariableNames = originalNames;

clear cleanupRs cleanupStmt
localSafeCloseJdbcResult(rs);
localSafeCloseJdbcStatement(stmt);
end

function value = localConvertJavaValue(rawValue)
value = [];

if isempty(rawValue)
    return;
end

if ischar(rawValue) || isnumeric(rawValue) || islogical(rawValue) || isdatetime(rawValue)
    value = rawValue;
    return;
end

if isstring(rawValue)
    value = char(rawValue);
    return;
end

try
    className = char(rawValue.getClass().getName());
catch
    try
        value = char(string(rawValue));
    catch
        value = rawValue;
    end
    return;
end

if strcmp(className, 'java.lang.String')
    value = char(rawValue);
    return;
end

if any(strcmp(className, { ...
        'java.lang.Integer', 'java.lang.Long', 'java.lang.Short', ...
        'java.lang.Double', 'java.lang.Float', 'java.math.BigDecimal'}))
    value = double(rawValue.doubleValue());
    return;
end

if strcmp(className, 'java.lang.Boolean')
    value = logical(rawValue.booleanValue());
    return;
end

if any(strcmp(className, {'java.sql.Date', 'java.sql.Timestamp', 'java.util.Date'}))
    value = datetime(double(rawValue.getTime()) / 1000, 'ConvertFrom', 'posixtime');
    return;
end

try
    value = char(string(rawValue));
catch
    value = rawValue;
end
end

function selectedTableNames = localSelectTableNamesForMode(schemas, mode)
tableNames = {schemas.Name};
if mode == "full" || isempty(schemas)
    selectedTableNames = tableNames;
    return;
end

metadataIdx = localFindMetadataSchemaIndex(schemas);
if isempty(metadataIdx)
    selectedTableNames = tableNames;
    return;
end

selectedTableNames = {schemas(metadataIdx).Name};
for idx = 1:numel(schemas)
    if idx == metadataIdx
        continue;
    end

    if localIsWaveformCandidateSchema(schemas(idx))
        selectedTableNames{end + 1} = schemas(idx).Name; %#ok<AGROW>
    end
end

selectedTableNames = unique(selectedTableNames, 'stable');
end

function metadataIdx = localFindMetadataSchemaIndex(schemas)
metadataIdx = [];
preferredNames = ["patientinformation", "patient_info", "patient"];

for idx = 1:numel(schemas)
    normalizedName = localNormalizeName(schemas(idx).Name);
    if any(normalizedName == preferredNames)
        metadataIdx = idx;
        return;
    end
end

for idx = 1:numel(schemas)
    if localSchemaHasColumns(schemas(idx), ["record", "recordnumber"]) && ...
            localSchemaHasColumns(schemas(idx), ["longprotocol", "protocol"]) && ...
            localSchemaHasColumns(schemas(idx), ["testdate", "testtime"])
        metadataIdx = idx;
        return;
    end
end
end

function tf = localIsWaveformCandidateSchema(schema)
normalizedName = localNormalizeName(schema.Name);
tf = false;

if localSchemaHasColumns(schema, ["record", "recordnumber"]) && ...
        localSchemaHasColumns(schema, ["data", "multidata", "lval", "rval", "value", "wavevalue", "datavalue", "samplevalue"])
    tf = true;
    return;
end

if contains(normalizedName, "lval") && localSchemaHasColumns(schema, ["record", "recordnumber"])
    tf = true;
end
end

function tf = localSchemaHasColumns(schema, aliases)
columns = lower(strtrim(string(schema.Columns)));
aliasValues = lower(strtrim(string(aliases)));
tf = false;

for idx = 1:numel(aliasValues)
    if any(columns == aliasValues(idx))
        tf = true;
        return;
    end
end
end

function normalized = localNormalizeName(name)
normalized = lower(regexprep(char(string(name)), '[^a-z0-9]+', ''));
normalized = string(normalized);
end

function jarPaths = localResolveUcanaccessJars()
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

function mirrorRoot = localEnsureMirrorRoot()
mirrorRoot = fullfile(tempdir, 'erg_ucanaccess');
if ~isfolder(mirrorRoot)
    mkdir(mirrorRoot);
end
end

function jdbcPath = localJdbcPath(folderPath)
folderPath = char(folderPath);
if ispc
    folderPath = strrep(folderPath, '\', '/');
end
jdbcPath = folderPath;
end

function dirMap = localListMirrorDirs(mirrorRoot)
dirMap = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if ~isfolder(mirrorRoot)
    return;
end

listing = dir(fullfile(mirrorRoot, 'UCanAccess_*'));
for idx = 1:numel(listing)
    if listing(idx).isdir
        dirMap(listing(idx).name) = true;
    end
end
end

function localCleanupMirrorDirs(mirrorRoot, existingMirrorDirs)
if ~isfolder(mirrorRoot)
    return;
end

listing = dir(fullfile(mirrorRoot, 'UCanAccess_*'));
for idx = 1:numel(listing)
    if ~listing(idx).isdir
        continue;
    end
    if isKey(existingMirrorDirs, listing(idx).name)
        continue;
    end

    target = fullfile(listing(idx).folder, listing(idx).name);
    try
        rmdir(target, 's');
    catch
    end
end
end

function localSafeCloseAdoConnection(conn)
try
    conn.Close;
catch
end
end

function localSafeCloseRecordset(rs)
try
    rs.Close;
catch
end
end

function localSafeCloseJdbcConnection(conn)
try
    conn.close();
catch
end
end

function localSafeCloseJdbcStatement(stmt)
try
    stmt.close();
catch
end
end

function localSafeCloseJdbcResult(rs)
try
    rs.close();
catch
end
end

function msg = localErrorMessage(err)
if isempty(err)
    msg = "Unknown error.";
    return;
end

msg = err.message;
end

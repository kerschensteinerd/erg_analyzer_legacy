function session = importLkcMdb(filePath)
% importLkcMdb Import a legacy LKC ERG MDB file into the normalized session format.

if ~isfile(filePath)
    error("ERG:FileNotFound", "File not found: %s", filePath);
end

mdbData = readMdbTables(filePath);
metadataTable = localFindMetadataTable(mdbData.Tables);

if isempty(metadataTable)
    error("ERG:MetadataTableNotFound", [ ...
        "Could not locate the LKC metadata table in '%s'.\n" ...
        "Expected a table similar to 'Patient Information'."], filePath);
end

waveformLookup = localBuildWaveformLookup(mdbData.Tables, metadataTable);
records = localBuildRecords(metadataTable, waveformLookup);

if isempty(records)
    error("ERG:NoWaveformsImported", [ ...
        "The database tables were readable, but no waveform records could be reconstructed.\n" ...
        "Check whether this LKC file stores waveform samples in 'Data', 'MultiData', or an LVAL-style table."]);
end

[records, subjectName, testDate] = localFinalizeRecords(records, metadataTable);

session = struct();
session.sourceFile = filePath;
session.subject = subjectName;
session.testDate = testDate;
session.importedAt = datetime("now");
session.analysisSettings = struct( ...
    "baselineWindowMs", [-25, 0], ...
    "peakSearchWindowMs", [0, 200], ...
    "importProvider", string(mdbData.Provider), ...
    "importTables", {mdbData.TableNames}, ...
    "numSessions", max([records.sessionIndex]));
session.records = records;
session.results = struct();
end

function metadataTable = localFindMetadataTable(tables)
metadataTable = table();
preferredNames = ["patientinformation", "patient_info", "patient"];

for idx = 1:numel(tables)
    normalizedName = localNormalizeName(tables(idx).Name);
    if any(normalizedName == preferredNames)
        metadataTable = tables(idx).Data;
        return;
    end
end

for idx = 1:numel(tables)
    tbl = tables(idx).Data;
    if localHasColumn(tbl, ["record", "recordnumber"]) && ...
            localHasColumn(tbl, ["longprotocol", "protocol"]) && ...
            localHasColumn(tbl, ["testdate", "testtime"])
        metadataTable = tbl;
        return;
    end
end
end

function waveformLookup = localBuildWaveformLookup(tables, metadataTable)
waveformLookup = containers.Map("KeyType", "char", "ValueType", "any");

recordNumbers = localGetNumericColumn(metadataTable, 1:height(metadataTable), ...
    ["record", "recordnumber"]);
validRecordMask = ~isnan(recordNumbers);
knownRecords = unique(recordNumbers(validRecordMask));

for idx = 1:numel(tables)
    tbl = tables(idx).Data;
    if isempty(tbl) || isequal(tbl, metadataTable)
        continue;
    end

    normalizedName = localNormalizeName(tables(idx).Name);
    if startsWith(normalizedName, "msys")
        continue;
    end

    if localHasColumn(tbl, ["record", "recordnumber"]) && ...
            localHasColumn(tbl, ["lval", "rval", "value", "wavevalue", "datavalue", "samplevalue"])
        localAddLongWaveTable(waveformLookup, tbl);
        continue;
    end

    if contains(normalizedName, "lval") && localHasColumn(tbl, ["record", "recordnumber"])
        localAddLongWaveTable(waveformLookup, tbl);
        continue;
    end

    if localHasColumn(tbl, ["data", "multidata"]) && localHasColumn(tbl, ["record", "recordnumber"])
        rowRecordNumbers = localGetNumericColumn(tbl, 1:height(tbl), ["record", "recordnumber"]);
        for rowIdx = 1:height(tbl)
            recNum = rowRecordNumbers(rowIdx);
            if isnan(recNum) || (~isempty(knownRecords) && ~ismember(recNum, knownRecords))
                continue;
            end

            waveform = localExtractWaveformFromRow(tbl, rowIdx);
            if ~isempty(waveform)
                waveformLookup(localMapKey(recNum)) = waveform(:);
            end
        end
    end
end
end

function localAddLongWaveTable(waveformLookup, tbl)
recordNumbers = localGetNumericColumn(tbl, 1:height(tbl), ["record", "recordnumber"]);
if all(isnan(recordNumbers))
    return;
end

sampleOrder = localGetNumericColumn(tbl, 1:height(tbl), ...
    ["sample", "sampleindex", "sampleid", "point", "pointindex", "index", "id"]);
valueColumn = localResolveColumn(tbl, ["lval", "rval", "value", "wavevalue", "datavalue", "samplevalue"]);
if strlength(valueColumn) == 0
    return;
end

sampleValues = tbl.(valueColumn);
uniqueRecords = unique(recordNumbers(~isnan(recordNumbers)));

for recIdx = 1:numel(uniqueRecords)
    recNum = uniqueRecords(recIdx);
    rowMask = recordNumbers == recNum;
    if any(~isnan(sampleOrder(rowMask)))
        [~, sortIdx] = sort(sampleOrder(rowMask));
        rowIndices = find(rowMask);
        rowIndices = rowIndices(sortIdx);
    else
        rowIndices = find(rowMask);
    end

    waveform = nan(numel(rowIndices), 1);
    for idx = 1:numel(rowIndices)
        waveform(idx) = localToDouble(localColumnValue(sampleValues, rowIndices(idx)));
    end

    waveform = waveform(~isnan(waveform));
    if ~isempty(waveform)
        waveformLookup(localMapKey(recNum)) = waveform(:);
    end
end
end

function records = localBuildRecords(metadataTable, waveformLookup)
nRows = height(metadataTable);
records = repmat(localEmptyRecord(), 1, nRows);
keepMask = false(1, nRows);

for rowIdx = 1:nRows
    recordNumber = localGetNumericValue(metadataTable, rowIdx, ["record", "recordnumber"]);
    if isnan(recordNumber)
        continue;
    end

    waveform = localExtractWaveformFromRow(metadataTable, rowIdx);
    if isempty(waveform)
        mapKey = localMapKey(recordNumber);
        if isKey(waveformLookup, mapKey)
            waveform = waveformLookup(mapKey);
        end
    end

    if isempty(waveform)
        continue;
    end

    sampleRate = localGetNumericValue(metadataTable, rowIdx, ...
        ["samplerate", "fcs500rate", "samplingrate", "sampleratehz"]);
    if isnan(sampleRate) || sampleRate <= 0
        sampleRate = 2000;
    end

    samplesPerWave = localGetNumericValue(metadataTable, rowIdx, ...
        ["samplesperwave", "sampleswave", "numberofsamples"]);
    if isnan(samplesPerWave) || samplesPerWave <= 0
        samplesPerWave = numel(waveform);
    end

    numAveraged = localGetNumericValue(metadataTable, rowIdx, ...
        ["numberaveraged", "numbertoaverage", "wavesb4update"]);

    prestimMs = localGetNumericValue(metadataTable, rowIdx, ...
        ["prestimbaseline", "prestimulusbaseline", "prestimms"]);
    if isnan(prestimMs)
        prestimMs = 25;
    end

    waveform = waveform(:);
    [waveform, waveformBlocks, numAveraged] = localNormalizeWaveform( ...
        waveform, samplesPerWave, numAveraged);
    samplesPerWave = numel(waveform);

    dtMs = 1000 / sampleRate;
    timeMs = ((0:(numel(waveform) - 1))' .* dtMs) - prestimMs;

    eye = localInferEye(metadataTable, rowIdx, recordNumber);
    stepNumber = localGetNumericValue(metadataTable, rowIdx, ["stepnumber", "step"]);
    if isnan(stepNumber)
        stepNumber = localInferStep(metadataTable, rowIdx);
    end

    includeFlag = localGetNumericValue(metadataTable, rowIdx, ["currentlykept", "keepflag", "included"]);
    if isnan(includeFlag)
        isIncluded = true;
    else
        isIncluded = includeFlag ~= 0;
    end

    records(rowIdx).recordNumber = recordNumber;
    records(rowIdx).stepNumber = stepNumber;
    records(rowIdx).mouseLabel = localGetStringValue(metadataTable, rowIdx, ...
        ["lastname", "identification", "firstname", "subject", "animal"]);
    records(rowIdx).mouseGroup = localGetStringValue(metadataTable, rowIdx, ...
        ["comments", "identification", "diagnosis"]);
    records(rowIdx).eye = char(eye);
    records(rowIdx).protocol = localGetStringValue(metadataTable, rowIdx, ["longprotocol", "protocol"]);
    records(rowIdx).flashDb = localGetNumericValue(metadataTable, rowIdx, ...
        ["ganzintensity", "flashdb", "flashd_b", "flashintensity", "dblflashintensity1"]);
    records(rowIdx).backgroundDb = localGetNumericValue(metadataTable, rowIdx, ...
        ["backgroundaper", "backgroundbrightness", "backgrounddb", "backgroundintensity"]);
    records(rowIdx).sampleRate = sampleRate;
    records(rowIdx).samplesPerWave = samplesPerWave;
    records(rowIdx).numAveraged = numAveraged;
    records(rowIdx).timeMs = timeMs;
    records(rowIdx).waveformUv = waveform;
    records(rowIdx).waveformBlocksUv = waveformBlocks;
    records(rowIdx).isIncluded = isIncluded;
    records(rowIdx).notes = "";

    keepMask(rowIdx) = true;
end

function [avgWaveform, waveformBlocks, numAveraged] = localNormalizeWaveform(waveform, samplesPerWave, numAveraged)
avgWaveform = waveform(:);
waveformBlocks = [];

if isempty(avgWaveform) || isnan(samplesPerWave) || samplesPerWave <= 0
    if isnan(numAveraged)
        numAveraged = 1;
    end
    return;
end

numSamples = numel(avgWaveform);
if numSamples < samplesPerWave
    if isnan(numAveraged)
        numAveraged = 1;
    end
    return;
end

blockCount = numSamples / samplesPerWave;
roundedBlocks = round(blockCount);
if abs(blockCount - roundedBlocks) < 1e-9 && roundedBlocks >= 1
    waveformBlocks = reshape(avgWaveform(1:(roundedBlocks * samplesPerWave)), samplesPerWave, roundedBlocks);
    avgWaveform = mean(waveformBlocks, 2, 'omitnan');
    if isnan(numAveraged) || numAveraged <= 0
        numAveraged = roundedBlocks;
    end
else
    avgWaveform = avgWaveform(1:samplesPerWave);
    if isnan(numAveraged) || numAveraged <= 0
        numAveraged = 1;
    end
end
end

records = records(keepMask);
end

function waveform = localExtractWaveformFromRow(tbl, rowIdx)
waveform = [];
candidateColumns = ["data", "multidata", "lval", "rval", "waveform"];

for aliasIdx = 1:numel(candidateColumns)
    columnName = localResolveColumn(tbl, candidateColumns(aliasIdx));
    if strlength(columnName) == 0
        continue;
    end

    value = localColumnValue(tbl.(columnName), rowIdx);
    waveform = localParseWaveformValue(value);
    if ~isempty(waveform)
        return;
    end
end
end

function waveform = localParseWaveformValue(value)
waveform = [];

if isempty(value)
    return;
end

if isnumeric(value)
    if isscalar(value)
        waveform = double(value);
    else
        waveform = double(value(:));
    end
    return;
end

if isstring(value)
    value = char(value);
end

if ischar(value)
    matches = regexp(value, '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match');
    if isempty(matches)
        return;
    end

    waveform = str2double(matches(:));
    waveform = waveform(~isnan(waveform));
    return;
end

try
    valueStr = char(string(value));
    waveform = localParseWaveformValue(valueStr);
catch
    waveform = [];
end
end

function [records, subjectName, testDate] = localFinalizeRecords(records, metadataTable)
[~, sortIdx] = sort([records.recordNumber]);
records = records(sortIdx);

subjectName = localInferSubjectName(metadataTable);
testDate = localInferTestDate(metadataTable);

stepCounters = containers.Map("KeyType", "char", "ValueType", "double");
for idx = 1:numel(records)
    if isnan(records(idx).stepNumber) || records(idx).stepNumber <= 0
        key = sprintf('%s|%s', char(string(records(idx).protocol)), char(string(records(idx).eye)));
        if isKey(stepCounters, key)
            stepCounters(key) = stepCounters(key) + 1;
        else
            stepCounters(key) = 1;
        end
        records(idx).stepNumber = stepCounters(key);
    end

    if strlength(string(records(idx).protocol)) == 0
        records(idx).protocol = "UNKNOWN";
    end
end

records = localAssignSessionIndices(records);
end

function records = localAssignSessionIndices(records)
if isempty(records)
    return;
end

mouseKeys = strings(1, numel(records));
for idx = 1:numel(records)
    mouseKeys(idx) = localStableMouseKey(records(idx));
end

hasStableMouseKeys = any(strlength(mouseKeys) > 0);

if hasStableMouseKeys
    sessionIndex = 0;
    currentMouseKey = "";
    for idx = 1:numel(records)
        mouseKey = mouseKeys(idx);
        if strlength(mouseKey) == 0
            if sessionIndex == 0
                sessionIndex = 1;
            end
        elseif sessionIndex == 0 || mouseKey ~= currentMouseKey
            sessionIndex = sessionIndex + 1;
            currentMouseKey = mouseKey;
        end

        records(idx).sessionIndex = sessionIndex;
    end
else
    eyes = string({records.eye});
    anchorIdx = find(eyes == "R", 1);
    if isempty(anchorIdx)
        anchorIdx = 1;
    end

    anchorEye = string(records(anchorIdx).eye);
    anchorSignature = localSessionSignature(records(anchorIdx));
    currentSession = 1;

    for idx = 1:numel(records)
        if idx > anchorIdx && string(records(idx).eye) == anchorEye
            if strcmp(localSessionSignature(records(idx)), anchorSignature)
                currentSession = currentSession + 1;
            end
        end

        records(idx).sessionIndex = currentSession;
    end
end

records = localAssignSessionLabels(records);
end

function signature = localSessionSignature(record)
signature = sprintf('%s|%.6g|%.6g', ...
    char(string(record.protocol)), record.stepNumber, record.flashDb);
end

function key = localSessionMouseKey(record)
key = localStableMouseKey(record);
end

function key = localStableMouseKey(record)
key = strtrim(string(record.mouseLabel));
end

function records = localAssignSessionLabels(records)
sessionIds = unique([records.sessionIndex], 'stable');
usedCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');

for idx = 1:numel(sessionIds)
    sessionId = sessionIds(idx);
    mask = [records.sessionIndex] == sessionId;
    sessionRecords = records(mask);

    label = "";
    for recIdx = 1:numel(sessionRecords)
        label = localPreferredLabel(sessionRecords(recIdx));
        if strlength(label) > 0
            break;
        end
    end

    if strlength(label) == 0
        label = "Session " + string(sessionId);
    end

    labelKey = char(label);
    if isKey(usedCounts, labelKey)
        usedCounts(labelKey) = usedCounts(labelKey) + 1;
        label = label + " (" + string(usedCounts(labelKey)) + ")";
    else
        usedCounts(labelKey) = 1;
    end

    sessionIndices = find(mask);
    for recIdx = 1:numel(sessionIndices)
        records(sessionIndices(recIdx)).sessionLabel = label;
    end
end
end

function label = localPreferredLabel(record)
label = string(record.mouseLabel);
if strlength(label) == 0
    label = string(record.mouseGroup);
    return;
end

group = strtrim(string(record.mouseGroup));
if strlength(group) > 0
    label = label + " [" + group + "]";
end
end

function subjectName = localInferSubjectName(tbl)
subjectName = "Unknown Subject";

lastName = localGetStringValue(tbl, 1, ["lastname", "subject", "animal"]);
firstName = localGetStringValue(tbl, 1, ["firstname"]);
middleInitial = localGetStringValue(tbl, 1, ["middleinitial"]);

parts = strings(0, 1);
if strlength(lastName) > 0
    parts(end + 1, 1) = lastName; %#ok<AGROW>
end
if strlength(firstName) > 0
    parts(end + 1, 1) = firstName; %#ok<AGROW>
end
if strlength(middleInitial) > 0
    parts(end + 1, 1) = middleInitial; %#ok<AGROW>
end

if ~isempty(parts)
    subjectName = strjoin(parts, " ");
end
end

function testDate = localInferTestDate(tbl)
testDate = datetime("today");
if height(tbl) == 0
    return;
end

rawValue = localGetValue(tbl, 1, ["testdate", "testtime"]);
testDate = localConvertToDatetime(rawValue);
end

function eye = localInferEye(tbl, rowIdx, recordNumber)
eye = "R";

waveLabel = upper(localGetStringValue(tbl, rowIdx, ["wavelabel", "eyestep", "eye"]));
if contains(waveLabel, "L")
    eye = "L";
    return;
elseif contains(waveLabel, "R")
    eye = "R";
    return;
end

channelNumber = localGetNumericValue(tbl, rowIdx, ["channelnumber", "channel"]);
if ~isnan(channelNumber)
    if mod(channelNumber, 2) == 0
        eye = "L";
    else
        eye = "R";
    end
    return;
end

if ~isnan(recordNumber) && mod(recordNumber, 2) == 0
    eye = "L";
end
end

function stepNumber = localInferStep(tbl, rowIdx)
stepNumber = NaN;
waveLabel = upper(localGetStringValue(tbl, rowIdx, ["wavelabel", "eyestep"]));
token = regexp(waveLabel, '([RL])\s*(\d+)', 'tokens', 'once');
if ~isempty(token)
    stepNumber = str2double(token{2});
end
end

function tf = localHasColumn(tbl, aliases)
tf = strlength(localResolveColumn(tbl, aliases)) > 0;
end

function columnName = localResolveColumn(tbl, aliases)
columnName = "";
aliases = string(aliases(:));

if isempty(tbl) || width(tbl) == 0
    return;
end

originalNames = localOriginalNames(tbl);
normalizedOriginal = localNormalizeName(originalNames);
variableNames = string(tbl.Properties.VariableNames);
normalizedVars = localNormalizeName(variableNames);
normalizedAliases = localNormalizeName(aliases);

for aliasIdx = 1:numel(normalizedAliases)
    matchIdx = find(normalizedOriginal == normalizedAliases(aliasIdx), 1);
    if ~isempty(matchIdx)
        columnName = variableNames(matchIdx);
        return;
    end

    matchIdx = find(normalizedVars == normalizedAliases(aliasIdx), 1);
    if ~isempty(matchIdx)
        columnName = variableNames(matchIdx);
        return;
    end
end
end

function originalNames = localOriginalNames(tbl)
originalNames = string(tbl.Properties.VariableNames);
if isstruct(tbl.Properties.UserData) && isfield(tbl.Properties.UserData, "OriginalVariableNames")
    originalNames = string(tbl.Properties.UserData.OriginalVariableNames);
end
end

function value = localGetValue(tbl, rowIdx, aliases)
value = [];
columnName = localResolveColumn(tbl, aliases);
if strlength(columnName) == 0 || rowIdx < 1 || rowIdx > height(tbl)
    return;
end

columnData = tbl.(columnName);
value = localColumnValue(columnData, rowIdx);
end

function values = localGetNumericColumn(tbl, rowIndices, aliases)
values = nan(numel(rowIndices), 1);
for idx = 1:numel(rowIndices)
    values(idx) = localGetNumericValue(tbl, rowIndices(idx), aliases);
end
end

function value = localGetNumericValue(tbl, rowIdx, aliases)
rawValue = localGetValue(tbl, rowIdx, aliases);
value = localToDouble(rawValue);
end

function value = localToDouble(rawValue)
value = NaN;

if isempty(rawValue)
    return;
end

if isnumeric(rawValue)
    if isempty(rawValue)
        return;
    end
    value = double(rawValue(1));
    return;
end

if islogical(rawValue)
    value = double(rawValue);
    return;
end

if isstring(rawValue)
    rawValue = char(rawValue);
end

if ischar(rawValue)
    token = regexp(rawValue, '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match', 'once');
    if ~isempty(token)
        value = str2double(token);
    end
    return;
end

try
    value = double(rawValue);
catch
    value = NaN;
end
end

function value = localGetStringValue(tbl, rowIdx, aliases)
rawValue = localGetValue(tbl, rowIdx, aliases);
if isempty(rawValue)
    value = "";
    return;
end

if isstring(rawValue)
    value = strtrim(rawValue(1));
    return;
end

if ischar(rawValue)
    value = string(strtrim(rawValue));
    return;
end

if isnumeric(rawValue)
    value = string(rawValue(1));
    return;
end

try
    value = string(rawValue);
catch
    value = "";
end
end

function dt = localConvertToDatetime(value)
dt = datetime("today");

if isa(value, "datetime")
    dt = value;
    return;
end

if isnumeric(value) && ~isempty(value) && ~isnan(value)
    try
        dt = datetime(value, "ConvertFrom", "excel");
        return;
    catch
    end
end

if ischar(value) || isstring(value)
    try
        dt = datetime(value);
        return;
    catch
    end
end
end

function key = localMapKey(recordNumber)
key = sprintf('%.0f', recordNumber);
end

function value = localColumnValue(columnData, rowIdx)
if iscell(columnData)
    value = columnData{rowIdx};
else
    value = columnData(rowIdx, :);
end
end

function normalized = localNormalizeName(names)
names = string(names);
normalized = lower(regexprep(names, '[^a-zA-Z0-9]+', ''));
end

function record = localEmptyRecord()
record = struct( ...
    "recordNumber", NaN, ...
    "stepNumber", NaN, ...
    "sessionIndex", NaN, ...
    "sessionLabel", "", ...
    "mouseLabel", "", ...
    "mouseGroup", "", ...
    "eye", "", ...
    "protocol", "", ...
    "flashDb", NaN, ...
    "backgroundDb", NaN, ...
    "sampleRate", NaN, ...
    "samplesPerWave", NaN, ...
    "numAveraged", NaN, ...
    "timeMs", [], ...
    "waveformUv", [], ...
    "waveformBlocksUv", [], ...
    "isIncluded", true, ...
    "notes", "");
end

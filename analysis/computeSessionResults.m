function session = computeSessionResults(session)
% computeSessionResults Compute summary tables and average traces.

arguments
    session (1, 1) struct
end

if ~isfield(session, "records") || isempty(session.records)
    session.results = struct( ...
        "rawTable", table(), ...
        "summaryTable", table(), ...
        "averageGroups", struct([]));
    return;
end

records = session.records;
nRecords = numel(records);

recordNumber = zeros(nRecords, 1);
stepNumber = zeros(nRecords, 1);
sessionIndex = zeros(nRecords, 1);
sessionLabel = strings(nRecords, 1);
eye = strings(nRecords, 1);
protocol = strings(nRecords, 1);
flashDb = zeros(nRecords, 1);
sampleRate = zeros(nRecords, 1);
samplesPerWave = zeros(nRecords, 1);
numAveraged = zeros(nRecords, 1);
isIncluded = false(nRecords, 1);
notes = strings(nRecords, 1);

for idx = 1:nRecords
    recordNumber(idx) = records(idx).recordNumber;
    stepNumber(idx) = records(idx).stepNumber;
    sessionIndex(idx) = records(idx).sessionIndex;
    sessionLabel(idx) = string(records(idx).sessionLabel);
    eye(idx) = string(records(idx).eye);
    protocol(idx) = string(records(idx).protocol);
    flashDb(idx) = records(idx).flashDb;
    sampleRate(idx) = records(idx).sampleRate;
    samplesPerWave(idx) = records(idx).samplesPerWave;
    if isfield(records, 'numAveraged') && ~isempty(records(idx).numAveraged)
        numAveraged(idx) = records(idx).numAveraged;
    else
        numAveraged(idx) = NaN;
    end
    isIncluded(idx) = logical(records(idx).isIncluded);
    notes(idx) = string(records(idx).notes);
end

rawTable = table( ...
    (1:nRecords)', recordNumber, stepNumber, sessionIndex, sessionLabel, eye, protocol, flashDb, ...
    sampleRate, samplesPerWave, numAveraged, isIncluded, notes, ...
    'VariableNames', { ...
    'RecordIndex', 'RecordNumber', 'StepNumber', 'SessionIndex', 'SessionLabel', 'Eye', 'Protocol', ...
    'FlashDb', 'SampleRate', 'SamplesPerWave', 'NumAveraged', 'IsIncluded', 'Notes'});

includedMask = rawTable.IsIncluded;
includedTable = rawTable(includedMask, :);

if isempty(includedTable)
    session.results = struct( ...
        "rawTable", rawTable, ...
        "summaryTable", table(), ...
        "averageGroups", struct([]));
    return;
end

nIncluded = height(includedTable);
averageGroups = repmat(localEmptyAverageGroup(), nIncluded, 1);
summaryRows = table('Size', [nIncluded, 16], ...
    'VariableTypes', {'double', 'double', 'double', 'string', 'string', 'string', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'RecordNumber', 'StepNumber', 'SessionIndex', 'SessionLabel', 'Protocol', 'Eye', 'FlashDb', 'NumAveraged', 'NumIncluded', 'Baseline', 'Min', 'Max', 'AWave', 'BWave', 'AWaveTms', 'BWaveTms'});

for rowIdx = 1:nIncluded
    recordIndex = includedTable.RecordIndex(rowIdx);
    record = records(recordIndex);
    timeMs = record.timeMs(:);
    avgWaveform = record.waveformUv(:);

    [baselineUv, minUv, maxUv, aWaveUv, bWaveUv, minTms, maxTms] = localComputeMeasures(timeMs, avgWaveform);

    averageGroups(rowIdx).RecordNumber = record.recordNumber;
    averageGroups(rowIdx).StepNumber = record.stepNumber;
    averageGroups(rowIdx).SessionIndex = record.sessionIndex;
    averageGroups(rowIdx).SessionLabel = string(record.sessionLabel);
    averageGroups(rowIdx).Protocol = string(record.protocol);
    averageGroups(rowIdx).Eye = string(record.eye);
    averageGroups(rowIdx).FlashDb = record.flashDb;
    averageGroups(rowIdx).NumIncluded = 1;
    averageGroups(rowIdx).NumAveraged = record.numAveraged;
    averageGroups(rowIdx).RecordNumbers = record.recordNumber;
    averageGroups(rowIdx).TimeMs = timeMs;
    averageGroups(rowIdx).AverageWaveformUv = avgWaveform;

    summaryRows.RecordNumber(rowIdx) = record.recordNumber;
    summaryRows.StepNumber(rowIdx) = record.stepNumber;
    summaryRows.SessionIndex(rowIdx) = record.sessionIndex;
    summaryRows.SessionLabel(rowIdx) = string(record.sessionLabel);
    summaryRows.Protocol(rowIdx) = string(record.protocol);
    summaryRows.Eye(rowIdx) = string(record.eye);
    summaryRows.FlashDb(rowIdx) = record.flashDb;
    summaryRows.NumAveraged(rowIdx) = record.numAveraged;
    summaryRows.NumIncluded(rowIdx) = 1;
    summaryRows.Baseline(rowIdx) = baselineUv;
    summaryRows.Min(rowIdx) = minUv;
    summaryRows.Max(rowIdx) = maxUv;
    summaryRows.AWave(rowIdx) = aWaveUv;
    summaryRows.BWave(rowIdx) = bWaveUv;
    summaryRows.AWaveTms(rowIdx) = minTms;
    summaryRows.BWaveTms(rowIdx) = maxTms;
end

summaryRows = sortrows(summaryRows, {'SessionIndex', 'Eye', 'RecordNumber'});

session.results = struct( ...
    "rawTable", rawTable, ...
    "summaryTable", summaryRows, ...
    "averageGroups", averageGroups);
end

function [baselineUv, minUv, maxUv, aWaveUv, bWaveUv, minTms, maxTms] = localComputeMeasures(timeMs, waveformUv)
baselineMask = timeMs < 0;
if any(baselineMask)
    baselineUv = mean(waveformUv(baselineMask), 'omitnan');
else
    baselineUv = 0;
end

% Legacy workbook behavior matches a 3-point moving average on the averaged
% trace before peak picking.
smoothWave = movmean(waveformUv, 3);

searchMask = timeMs >= 0 & timeMs <= 200;
searchTime = timeMs(searchMask);
searchWave = smoothWave(searchMask);

[maxUv, maxIdx] = max(searchWave);
[minUv, minIdx] = min(searchWave(1:maxIdx));

aWaveUv = baselineUv - minUv;
bWaveUv = maxUv - minUv;
minTms = searchTime(minIdx);
maxTms = searchTime(maxIdx);
end

function group = localEmptyAverageGroup()
group = struct( ...
    "RecordNumber", NaN, ...
    "StepNumber", NaN, ...
    "SessionIndex", NaN, ...
    "SessionLabel", "", ...
    "Protocol", "", ...
    "Eye", "", ...
    "FlashDb", NaN, ...
    "NumAveraged", NaN, ...
    "NumIncluded", NaN, ...
    "RecordNumbers", [], ...
    "TimeMs", [], ...
    "AverageWaveformUv", []);
end

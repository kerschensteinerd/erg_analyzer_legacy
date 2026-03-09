function session = buildDemoSession()
% buildDemoSession Create a synthetic ERG session for UI development.

rng(11);

timeMs = linspace(-25, 230.5, 512)';
protocols = ["FLIESLER 2", "MOUSE CONES DIM BKG"];
flashLevels = [-60, -40, -28, -20, -16];
eyes = ["R", "L"];

records = repmat(localEmptyRecord(), 1, numel(protocols) * numel(flashLevels) * numel(eyes));
recordIdx = 1;
recordNumber = 33;

for protocolIdx = 1:numel(protocols)
    for eyeIdx = 1:numel(eyes)
        for flashIdx = 1:numel(flashLevels)
            flashDb = flashLevels(flashIdx);
            eye = eyes(eyeIdx);
            protocol = protocols(protocolIdx);

            aScale = 20 + 2 * flashIdx + 3 * (protocolIdx - 1) + 1.5 * (eye == "L");
            bScale = 80 + 35 * flashIdx + 15 * (protocolIdx - 1) + 5 * (eye == "L");

            waveformUv = localWaveform(timeMs, aScale, bScale);

            records(recordIdx).recordNumber = recordNumber;
            records(recordIdx).stepNumber = flashIdx;
            records(recordIdx).sessionIndex = protocolIdx;
            records(recordIdx).sessionLabel = sprintf('Session %d', protocolIdx);
            records(recordIdx).eye = eye;
            records(recordIdx).protocol = protocol;
            records(recordIdx).flashDb = flashDb;
            records(recordIdx).backgroundDb = NaN;
            records(recordIdx).sampleRate = 2000;
            records(recordIdx).samplesPerWave = numel(timeMs);
            records(recordIdx).numAveraged = 10;
            records(recordIdx).timeMs = timeMs;
            records(recordIdx).waveformUv = waveformUv;
            records(recordIdx).waveformBlocksUv = [];
            records(recordIdx).isIncluded = true;
            records(recordIdx).notes = "";

            recordIdx = recordIdx + 1;
            recordNumber = recordNumber + 1;
        end
    end
end

session = struct();
session.sourceFile = "DEMO_SESSION";
session.subject = "Mouse 2";
session.testDate = datetime(2023, 6, 6);
session.importedAt = datetime("now");
session.analysisSettings = struct( ...
    "baselineWindowMs", [-25, 0], ...
    "peakSearchWindowMs", [0, 200]);
session.records = records;
session.results = struct();
end

function waveformUv = localWaveform(timeMs, aScale, bScale)
noise = randn(size(timeMs)) * 1.5;
aCenter = 18 + randn() * 2;
bCenter = 55 + randn() * 4;
aWidth = 7 + rand() * 2;
bWidth = 18 + rand() * 4;

aComponent = -aScale .* exp(-0.5 .* ((timeMs - aCenter) ./ aWidth) .^ 2);
bComponent = bScale .* exp(-0.5 .* ((timeMs - bCenter) ./ bWidth) .^ 2);
drift = 2 .* sin(timeMs ./ 28);

waveformUv = aComponent + bComponent + drift + noise;
end

function record = localEmptyRecord()
record = struct( ...
    "recordNumber", NaN, ...
    "stepNumber", NaN, ...
    "sessionIndex", NaN, ...
    "sessionLabel", "", ...
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

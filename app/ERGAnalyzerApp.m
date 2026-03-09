classdef ERGAnalyzerApp < matlab.apps.AppBase
    % ERGAnalyzerApp MATLAB desktop scaffold for LKC ERG analysis.

    properties (Access = public)
        UIFigure matlab.ui.Figure
        GridLayout matlab.ui.container.GridLayout
        TabGroup matlab.ui.container.TabGroup

        ImportTab matlab.ui.container.Tab
        FilePathField matlab.ui.control.EditField
        SelectFileButton matlab.ui.control.Button
        ImportButton matlab.ui.control.Button
        SummaryTextArea matlab.ui.control.TextArea
        ImportLogArea matlab.ui.control.TextArea

        RawTab matlab.ui.container.Tab
        RawSessionDropDown matlab.ui.control.DropDown
        RawProtocolDropDown matlab.ui.control.DropDown
        RawEyeDropDown matlab.ui.control.DropDown
        RawFlashDropDown matlab.ui.control.DropDown
        ShowExcludedCheckBox matlab.ui.control.CheckBox
        ExcludeSelectedButton matlab.ui.control.Button
        IncludeSelectedButton matlab.ui.control.Button
        RawAxes matlab.ui.control.UIAxes
        RawTable matlab.ui.control.Table
        RawExportFigureButton matlab.ui.control.Button
        RawExportTraceDataButton matlab.ui.control.Button

        AverageTab matlab.ui.container.Tab
        AvgSessionDropDown matlab.ui.control.DropDown
        AvgProtocolDropDown matlab.ui.control.DropDown
        AvgEyeDropDown matlab.ui.control.DropDown
        AverageAxes matlab.ui.control.UIAxes
        AverageTable matlab.ui.control.Table
        AvgExportFigureButton matlab.ui.control.Button
        AvgExportTraceDataButton matlab.ui.control.Button

        MeasuresTab matlab.ui.container.Tab
        MeasuresSessionDropDown matlab.ui.control.DropDown
        MeasuresTable matlab.ui.control.Table

        ExportTab matlab.ui.container.Tab
        ExportPathField matlab.ui.control.EditField
        BrowseExportButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        SaveMatButton matlab.ui.control.Button
    end

    properties (Access = private)
        Session struct = struct()
        FilteredRawRecordIndices double = []
        SelectedRawRows double = []
        LastInputDirectory string = string(pwd)
        LastOutputDirectory string = string(pwd)
    end

    methods (Access = private)
        function startupFcn(app)
            app.appendLog("App started.");
            app.appendLog("Select a .mdb or normalized .mat file to begin.");
            app.SummaryTextArea.Value = { ...
                'No session loaded.'; ...
                'Expected workflow:'; ...
                '1. Import an MDB file or normalized MAT session.'; ...
                '2. Review traces and exclude noisy records.'; ...
                '3. Inspect measures and export summary tables.'};
            app.ExportPathField.Value = fullfile(pwd, "erg_summary.xlsx");
            app.configureEmptyViews();
        end

        function configureEmptyViews(app)
            app.RawProtocolDropDown.Items = {'All'};
            app.RawProtocolDropDown.Value = "All";
            app.RawSessionDropDown.Items = {'All'};
            app.RawSessionDropDown.Value = "All";
            app.RawEyeDropDown.Items = {'All', 'R', 'L'};
            app.RawEyeDropDown.Value = "All";
            app.RawFlashDropDown.Items = {'All'};
            app.RawFlashDropDown.Value = "All";

            app.AvgProtocolDropDown.Items = {'All'};
            app.AvgProtocolDropDown.Value = "All";
            app.AvgSessionDropDown.Items = {'All'};
            app.AvgSessionDropDown.Value = "All";
            app.AvgEyeDropDown.Items = {'All', 'R', 'L'};
            app.AvgEyeDropDown.Value = "All";

            app.MeasuresSessionDropDown.Items = {'All'};
            app.MeasuresSessionDropDown.Value = "All";

            app.RawTable.Data = table();
            app.AverageTable.Data = table();
            app.MeasuresTable.Data = table();

            cla(app.RawAxes);
            title(app.RawAxes, "Raw Traces");
            xlabel(app.RawAxes, "Time (ms)");
            ylabel(app.RawAxes, "Amplitude (\muV)");

            cla(app.AverageAxes);
            title(app.AverageAxes, "Averaged Responses");
            xlabel(app.AverageAxes, "Time (ms)");
            ylabel(app.AverageAxes, "Amplitude (\muV)");
        end

        function SelectFileButtonPushed(app, ~)
            startPath = app.resolveBrowseStartPath(app.FilePathField.Value, app.LastInputDirectory, '*.mdb');
            [fileName, fileDir] = uigetfile({'*.mdb;*.mat', 'ERG session files (*.mdb, *.mat)'}, ...
                "Select ERG Session", startPath);
            if isequal(fileName, 0)
                return;
            end

            app.FilePathField.Value = fullfile(fileDir, fileName);
            app.LastInputDirectory = string(fileDir);
        end

        function ImportButtonPushed(app, ~)
            filePath = strtrim(app.FilePathField.Value);
            if strlength(filePath) == 0
                app.appendLog("No input file selected.");
                return;
            end

            try
                app.appendLog("Importing " + string(filePath));
                session = importLkcFile(filePath);
                session = computeSessionResults(session);
                app.Session = session;
                app.updateForSession();
                app.appendLog("Import completed.");
            catch err
                app.appendLog("Import failed: " + string(err.message));
                uialert(app.UIFigure, err.message, "Import failed");
            end
        end

        function updateForSession(app)
            summaryLines = [ ...
                "Source: " + string(app.Session.sourceFile); ...
                "Subject: " + string(app.Session.subject); ...
                "Test date: " + string(app.Session.testDate); ...
                "Imported: " + string(app.Session.importedAt); ...
                "Records: " + string(numel(app.Session.records)); ...
                "Sessions: " + string(max(app.Session.results.rawTable.SessionIndex))];
            app.SummaryTextArea.Value = cellstr(summaryLines(:));

            rawTable = app.Session.results.rawTable;
            protocols = ["All"; unique(string(rawTable.Protocol))];
            sessionLabels = unique(string(rawTable.SessionLabel), 'stable');
            sessionLabels = sessionLabels(strlength(sessionLabels) > 0);
            sessions = ["All"; sessionLabels];
            flashValues = unique(rawTable.FlashDb(~isnan(rawTable.FlashDb)));
            flashLabels = "All";
            if ~isempty(flashValues)
                flashLabels = ["All"; string(flashValues)];
            end
            app.RawProtocolDropDown.Items = cellstr(protocols);
            app.RawProtocolDropDown.Value = "All";
            app.RawSessionDropDown.Items = cellstr(sessions);
            app.RawSessionDropDown.Value = "All";
            app.RawFlashDropDown.Items = cellstr(flashLabels);
            app.RawFlashDropDown.Value = "All";
            app.AvgProtocolDropDown.Items = cellstr(protocols);
            app.AvgProtocolDropDown.Value = "All";
            app.AvgSessionDropDown.Items = cellstr(sessions);
            app.AvgSessionDropDown.Value = "All";
            app.MeasuresSessionDropDown.Items = cellstr(sessions);
            app.MeasuresSessionDropDown.Value = "All";

            app.refreshRawView();
            app.refreshAverageView();
            app.refreshMeasuresView();
        end

        function refreshRawView(app, ~, ~)
            if ~isfield(app.Session, "results") || isempty(app.Session.results.rawTable)
                app.RawTable.Data = table();
                app.clearAxes(app.RawAxes);
                return;
            end

            filtered = app.getFilteredRawTable();
            app.FilteredRawRecordIndices = filtered.RecordIndex;
            hiddenColumns = ["RecordIndex", "SessionIndex"];
            app.RawTable.Data = filtered(:, setdiff(filtered.Properties.VariableNames, hiddenColumns, "stable"));
            app.SelectedRawRows = [];

            app.clearAxes(app.RawAxes);
            hold(app.RawAxes, "on");

            for rowIdx = 1:height(filtered)
                record = app.Session.records(filtered.RecordIndex(rowIdx));
                if filtered.IsIncluded(rowIdx)
                    color = [0.12, 0.47, 0.71];
                    lineStyle = "-";
                else
                    color = [0.6, 0.6, 0.6];
                    lineStyle = "--";
                end

                rawBlockColor = min(color + 0.45, 1);
                if isfield(record, 'waveformBlocksUv') && ~isempty(record.waveformBlocksUv)
                    for blockIdx = 1:size(record.waveformBlocksUv, 2)
                        plot(app.RawAxes, record.timeMs, record.waveformBlocksUv(:, blockIdx), ...
                            "Color", rawBlockColor, "LineStyle", lineStyle, "LineWidth", 0.5);
                    end
                    plot(app.RawAxes, record.timeMs, record.waveformUv, ...
                        "Color", color, "LineStyle", lineStyle, "LineWidth", 1.3);
                else
                    plot(app.RawAxes, record.timeMs, record.waveformUv, ...
                        "Color", color, "LineStyle", lineStyle, "LineWidth", 1.0);
                end
            end

            hold(app.RawAxes, "off");
            grid(app.RawAxes, "on");
            title(app.RawAxes, "Raw Traces");
            xlabel(app.RawAxes, "Time (ms)");
            ylabel(app.RawAxes, "Amplitude (\muV)");
        end

        function refreshAverageView(app, ~, ~)
            if ~isfield(app.Session, "results") || isempty(app.Session.results.rawTable)
                app.AverageTable.Data = table();
                app.clearAxes(app.AverageAxes);
                return;
            end

            filtered = app.getFilteredAverageRawTable();
            if isempty(filtered)
                app.AverageTable.Data = table();
                app.clearAxes(app.AverageAxes);
                return;
            end

            app.clearAxes(app.AverageAxes);
            hold(app.AverageAxes, "on");

            plotRows = filtered(:, {'RecordNumber', 'StepNumber', 'SessionIndex', 'SessionLabel', 'Protocol', 'Eye', 'FlashDb', 'NumAveraged'});
            flashValues = plotRows.FlashDb;
            flashValues = unique(flashValues(~isnan(flashValues)));
            flashValues = sort(flashValues);
            cmap = winter(max(numel(flashValues), 1));
            flashLabelsShown = strings(0, 1);

            for idx = 1:height(plotRows)
                record = app.Session.records(filtered.RecordIndex(idx));

                color = app.winterColorForFlash(plotRows.FlashDb(idx), flashValues, cmap);
                flashLabel = app.formatFlashLabel(plotRows.FlashDb(idx));
                if any(flashLabelsShown == flashLabel)
                    showInLegend = false;
                else
                    showInLegend = true;
                    flashLabelsShown(end + 1, 1) = flashLabel; %#ok<AGROW>
                end

                traceHandle = plot(app.AverageAxes, record.timeMs(:), record.waveformUv(:), ...
                    "Color", color, ...
                    "LineStyle", "-", ...
                    "LineWidth", 1.6, ...
                    "DisplayName", char(flashLabel));
                if ~showInLegend
                    traceHandle.Annotation.LegendInformation.IconDisplayStyle = 'off';
                end
            end

            hold(app.AverageAxes, "off");
            grid(app.AverageAxes, "on");
            title(app.AverageAxes, app.buildAverageTitle(height(plotRows)));
            xlabel(app.AverageAxes, "Time (ms)");
            ylabel(app.AverageAxes, "Amplitude (\muV)");
            if height(plotRows) <= 20
                legend(app.AverageAxes, "Location", "best");
            else
                legend(app.AverageAxes, "off");
            end

            plotRows = sortrows(plotRows, {'SessionIndex', 'Eye', 'RecordNumber'});
            app.AverageTable.Data = plotRows(:, setdiff(plotRows.Properties.VariableNames, "SessionIndex", "stable"));
        end

        function refreshMeasuresView(app, ~, ~)
            if isfield(app.Session, "results") && isfield(app.Session.results, "summaryTable")
                measuresTable = app.getFilteredMeasuresTable();
                if any(strcmp(measuresTable.Properties.VariableNames, 'SessionIndex'))
                    measuresTable = measuresTable(:, setdiff(measuresTable.Properties.VariableNames, "SessionIndex", "stable"));
                end
                app.MeasuresTable.Data = measuresTable;
            else
                app.MeasuresTable.Data = table();
            end
        end

        function measuresTable = getFilteredMeasuresTable(app)
            measuresTable = table();
            if ~isfield(app.Session, "results") || ~isfield(app.Session.results, "summaryTable")
                return;
            end

            measuresTable = app.Session.results.summaryTable;
            sessionFilter = string(app.MeasuresSessionDropDown.Value);
            if sessionFilter ~= "All"
                measuresTable = measuresTable(string(measuresTable.SessionLabel) == sessionFilter, :);
            end
        end

        function rawTable = getFilteredRawTable(app)
            rawTable = table();
            if ~isfield(app.Session, "results") || isempty(app.Session.results.rawTable)
                return;
            end

            rawTable = app.Session.results.rawTable;
            sessionFilter = string(app.RawSessionDropDown.Value);
            protocolFilter = string(app.RawProtocolDropDown.Value);
            eyeFilter = string(app.RawEyeDropDown.Value);
            flashFilter = string(app.RawFlashDropDown.Value);
            includeExcluded = app.ShowExcludedCheckBox.Value;

            mask = true(height(rawTable), 1);
            if sessionFilter ~= "All"
                mask = mask & string(rawTable.SessionLabel) == sessionFilter;
            end
            if protocolFilter ~= "All"
                mask = mask & string(rawTable.Protocol) == protocolFilter;
            end
            if eyeFilter ~= "All"
                mask = mask & string(rawTable.Eye) == eyeFilter;
            end
            if flashFilter ~= "All"
                flashValue = str2double(flashFilter);
                if ~isnan(flashValue)
                    mask = mask & rawTable.FlashDb == flashValue;
                end
            end
            if ~includeExcluded
                mask = mask & rawTable.IsIncluded;
            end

            rawTable = rawTable(mask, :);
        end

        function avgTable = getFilteredAverageRawTable(app)
            avgTable = table();
            if ~isfield(app.Session, "results") || isempty(app.Session.results.rawTable)
                return;
            end

            avgTable = app.Session.results.rawTable;
            sessionFilter = string(app.AvgSessionDropDown.Value);
            protocolFilter = string(app.AvgProtocolDropDown.Value);
            eyeFilter = string(app.AvgEyeDropDown.Value);
            mask = true(height(avgTable), 1);

            if sessionFilter ~= "All"
                mask = mask & strcmp(cellstr(string(avgTable.SessionLabel)), char(sessionFilter));
            end
            if protocolFilter ~= "All"
                mask = mask & strcmp(cellstr(string(avgTable.Protocol)), char(protocolFilter));
            end
            if eyeFilter ~= "All"
                mask = mask & strcmp(cellstr(string(avgTable.Eye)), char(eyeFilter));
            end
            mask = mask & avgTable.IsIncluded;

            avgTable = avgTable(mask, :);
        end

        function color = winterColorForFlash(app, flashValue, flashValues, cmap) %#ok<INUSD>
            if isempty(flashValues) || isnan(flashValue)
                color = cmap(1, :);
                return;
            end

            matchIdx = find(flashValues == flashValue, 1, 'first');
            if isempty(matchIdx)
                matchIdx = 1;
            end
            color = cmap(matchIdx, :);
        end

        function label = formatFlashLabel(app, flashValue) %#ok<INUSD>
            if isnan(flashValue)
                label = "Unknown";
            elseif abs(flashValue - round(flashValue)) < 1e-6
                label = string(sprintf('%.0f dB', flashValue));
            else
                label = string(sprintf('%.3g dB', flashValue));
            end
        end

        function titleText = buildAverageTitle(app, traceCount)
            sessionFilter = string(app.AvgSessionDropDown.Value);
            protocolFilter = string(app.AvgProtocolDropDown.Value);
            eyeFilter = string(app.AvgEyeDropDown.Value);

            if sessionFilter == "All"
                sessionPart = "all sessions";
            else
                sessionPart = sessionFilter;
            end

            if protocolFilter == "All"
                protocolPart = "all protocols";
            else
                protocolPart = protocolFilter;
            end

            if eyeFilter == "All"
                eyePart = "both eyes";
            elseif eyeFilter == "R"
                eyePart = "right eye";
            else
                eyePart = "left eye";
            end

            titleText = sprintf('Averaged Responses: %s, %s, %s (%d traces)', ...
                char(sessionPart), char(protocolPart), char(eyePart), traceCount);
        end

        function clearAxes(app, ax) %#ok<INUSD>
            hold(ax, "off");
            legend(ax, "off");
            allChildren = findall(ax);
            allChildren(allChildren == ax) = [];
            if ~isempty(allChildren)
                delete(allChildren);
            end
            cla(ax);
        end

        function startPath = resolveBrowseStartPath(app, currentValue, fallbackDirectory, defaultName) %#ok<INUSD>
            currentText = strtrim(char(string(currentValue)));
            if ~isempty(currentText)
                if isfolder(currentText)
                    startPath = currentText;
                    return;
                end
                currentFolder = fileparts(currentText);
                if ~isempty(currentFolder) && isfolder(currentFolder)
                    if nargin >= 4 && ~isempty(defaultName)
                        startPath = fullfile(currentFolder, defaultName);
                    else
                        startPath = currentText;
                    end
                    return;
                end
            end

            fallbackText = strtrim(char(string(fallbackDirectory)));
            if ~isempty(fallbackText) && isfolder(fallbackText)
                if nargin >= 4 && ~isempty(defaultName)
                    startPath = fullfile(fallbackText, defaultName);
                else
                    startPath = fallbackText;
                end
                return;
            end

            if nargin >= 4 && ~isempty(defaultName)
                startPath = fullfile(pwd, defaultName);
            else
                startPath = pwd;
            end
        end

        function RawTableSelectionChanged(app, event)
            if isempty(event.Indices)
                app.SelectedRawRows = [];
                return;
            end

            app.SelectedRawRows = unique(event.Indices(:, 1), "stable");
        end

        function ExcludeSelectedButtonPushed(app, ~)
            app.setSelectedRecordsIncluded(false);
        end

        function IncludeSelectedButtonPushed(app, ~)
            app.setSelectedRecordsIncluded(true);
        end

        function setSelectedRecordsIncluded(app, includeValue)
            if isempty(app.SelectedRawRows) || isempty(app.FilteredRawRecordIndices)
                app.appendLog("No records selected.");
                return;
            end

            selectedIndices = app.FilteredRawRecordIndices(app.SelectedRawRows);
            for idx = 1:numel(selectedIndices)
                app.Session.records(selectedIndices(idx)).isIncluded = includeValue;
            end

            app.Session = computeSessionResults(app.Session);
            app.refreshRawView();
            app.refreshAverageView();
            app.refreshMeasuresView();

            if includeValue
                app.appendLog("Selected records marked included.");
            else
                app.appendLog("Selected records excluded.");
            end
        end

        function BrowseExportButtonPushed(app, ~)
            startPath = app.resolveBrowseStartPath(app.ExportPathField.Value, app.LastOutputDirectory, "erg_summary.xlsx");
            [fileName, fileDir] = uiputfile("*.xlsx", "Export ERG Summary", startPath);
            if isequal(fileName, 0)
                return;
            end

            app.ExportPathField.Value = fullfile(fileDir, fileName);
            app.LastOutputDirectory = string(fileDir);
        end

        function ExportButtonPushed(app, ~)
            if isempty(fieldnames(app.Session))
                app.appendLog("Nothing to export.");
                return;
            end

            outFile = strtrim(app.ExportPathField.Value);
            if strlength(outFile) == 0
                app.appendLog("No export path selected.");
                return;
            end

            try
                summaryTable = app.getFilteredMeasuresTable();
                rawTable = app.Session.results.rawTable;
                if ~isempty(summaryTable) && any(strcmp(summaryTable.Properties.VariableNames, 'RecordNumber'))
                    rawTable = rawTable(ismember(rawTable.RecordNumber, summaryTable.RecordNumber), :);
                end
                exportSessionSummary(app.Session, outFile, summaryTable, rawTable);
                app.appendLog("Exported summary to " + string(outFile));
            catch err
                app.appendLog("Export failed: " + string(err.message));
                uialert(app.UIFigure, err.message, "Export failed");
            end
        end

        function SaveMatButtonPushed(app, ~)
            if isempty(fieldnames(app.Session))
                app.appendLog("Nothing to save.");
                return;
            end

            [fileName, fileDir] = uiputfile("*.mat", "Save ERG Session", "erg_session.mat");
            if isequal(fileName, 0)
                return;
            end

            outFile = fullfile(fileDir, fileName);
            app.LastOutputDirectory = string(fileDir);

            try
                saveSessionMat(app.Session, outFile);
                app.appendLog("Saved session to " + string(outFile));
            catch err
                app.appendLog("Save failed: " + string(err.message));
                uialert(app.UIFigure, err.message, "Save failed");
            end
        end

        function [displayName, traceTable, traceStruct] = buildDisplayTraceData(app, displayName)
            tableParts = {};

            if displayName == "Raw Traces"
                rawTable = app.getFilteredRawTable();
                for rowIdx = 1:height(rawTable)
                    record = app.Session.records(rawTable.RecordIndex(rowIdx));
                    if isfield(record, 'waveformBlocksUv') && ~isempty(record.waveformBlocksUv)
                        for blockIdx = 1:size(record.waveformBlocksUv, 2)
                            tableParts{end + 1, 1} = app.makeTraceTable( ... %#ok<AGROW>
                                displayName, rawTable(rowIdx, :), "Sweep", blockIdx, ...
                                record.timeMs(:), record.waveformBlocksUv(:, blockIdx));
                        end
                    end
                    tableParts{end + 1, 1} = app.makeTraceTable( ... %#ok<AGROW>
                        displayName, rawTable(rowIdx, :), "Average", 0, ...
                        record.timeMs(:), record.waveformUv(:));
                end
            else
                avgTable = app.getFilteredAverageRawTable();
                for idx = 1:height(avgTable)
                    record = app.Session.records(avgTable.RecordIndex(idx));
                    metadataRow = table( ...
                        avgTable.RecordNumber(idx), avgTable.StepNumber(idx), avgTable.SessionLabel(idx), ...
                        avgTable.Eye(idx), avgTable.Protocol(idx), avgTable.FlashDb(idx), ...
                        'VariableNames', {'RecordNumber', 'StepNumber', 'SessionLabel', 'Eye', 'Protocol', 'FlashDb'});
                    tableParts{end + 1, 1} = app.makeTraceTable( ... %#ok<AGROW>
                        displayName, metadataRow, "Average", 0, ...
                        record.timeMs(:), record.waveformUv(:));
                end
            end

            if isempty(tableParts)
                traceTable = table();
            else
                traceTable = vertcat(tableParts{:});
            end

            traceStruct = struct( ...
                'Display', char(displayName), ...
                'SourceFile', char(string(app.Session.sourceFile)), ...
                'ExportedAt', char(string(datetime('now'))), ...
                'TraceTable', traceTable);
        end

        function exportDisplayFigure(app, displayName)
            if isempty(fieldnames(app.Session))
                app.appendLog("Nothing to export.");
                return;
            end

            if displayName == "Raw Traces"
                sourceAxes = app.RawAxes;
                defaultName = "erg_raw_display.pdf";
            else
                sourceAxes = app.AverageAxes;
                defaultName = "erg_average_display.pdf";
            end

            if isempty(sourceAxes.Children)
                app.appendLog("Selected display has no plotted traces.");
                return;
            end

            [fileName, fileDir] = uiputfile({'*.pdf', 'PDF (*.pdf)'; '*.fig', 'MATLAB Figure (*.fig)'}, ...
                "Export Display Figure", app.resolveBrowseStartPath("", app.LastOutputDirectory, defaultName));
            if isequal(fileName, 0)
                return;
            end

            outFile = fullfile(fileDir, fileName);
            app.LastOutputDirectory = string(fileDir);
            fig = figure('Visible', 'off', 'Color', 'w');
            cleanupObj = onCleanup(@() localDeleteFigure(fig));
            axesHandle = axes(fig);
            copyobj(allchild(sourceAxes), axesHandle);
            set(axesHandle, 'XLim', sourceAxes.XLim, 'YLim', sourceAxes.YLim);
            axesHandle.XGrid = sourceAxes.XGrid;
            axesHandle.YGrid = sourceAxes.YGrid;
            box(axesHandle, sourceAxes.Box);
            title(axesHandle, sourceAxes.Title.String);
            xlabel(axesHandle, sourceAxes.XLabel.String);
            ylabel(axesHandle, sourceAxes.YLabel.String);

            visibleChildren = findobj(axesHandle.Children, '-property', 'DisplayName');
            hasLegendEntries = false;
            for idx = 1:numel(visibleChildren)
                childName = string(visibleChildren(idx).DisplayName);
                if strlength(childName) > 0 && string(visibleChildren(idx).HandleVisibility) ~= "off"
                    hasLegendEntries = true;
                    break;
                end
            end
            if hasLegendEntries
                legend(axesHandle, 'show', 'Location', 'best');
            end

            try
                [~, ~, ext] = fileparts(outFile);
                if strcmpi(ext, '.fig')
                    savefig(fig, outFile);
                else
                    set(fig, 'PaperPositionMode', 'auto');
                    print(fig, outFile, '-dpdf', '-bestfit');
                end
                app.appendLog("Exported " + displayName + " figure to " + string(outFile));
            catch err
                app.appendLog("Figure export failed: " + string(err.message));
                uialert(app.UIFigure, err.message, "Figure export failed");
            end
            clear cleanupObj
        end

        function exportDisplayTraceData(app, displayName)
            if isempty(fieldnames(app.Session))
                app.appendLog("Nothing to export.");
                return;
            end

            [displayName, traceTable, traceStruct] = app.buildDisplayTraceData(displayName);
            if isempty(traceTable)
                app.appendLog("Selected display has no trace data to export.");
                return;
            end

            defaultStem = regexprep(lower(char(displayName)), '\s+', '_');
            [fileName, fileDir] = uiputfile({'*.xlsx', 'Excel Workbook (*.xlsx)'; '*.mat', 'MAT-file (*.mat)'}, ...
                "Export Trace Data", app.resolveBrowseStartPath("", app.LastOutputDirectory, [defaultStem '_traces.xlsx']));
            if isequal(fileName, 0)
                return;
            end

            outFile = fullfile(fileDir, fileName);
            app.LastOutputDirectory = string(fileDir);
            try
                [~, ~, ext] = fileparts(outFile);
                if strcmpi(ext, '.mat')
                    save(outFile, 'displayName', 'traceTable', 'traceStruct', '-mat');
                else
                    writetable(traceTable, outFile);
                end
                app.appendLog("Exported " + displayName + " trace data to " + string(outFile));
            catch err
                app.appendLog("Trace export failed: " + string(err.message));
                uialert(app.UIFigure, err.message, "Trace export failed");
            end
        end

        function RawExportFigureButtonPushed(app, ~)
            app.exportDisplayFigure("Raw Traces");
        end

        function RawExportTraceDataButtonPushed(app, ~)
            app.exportDisplayTraceData("Raw Traces");
        end

        function AvgExportFigureButtonPushed(app, ~)
            app.exportDisplayFigure("Averages");
        end

        function AvgExportTraceDataButtonPushed(app, ~)
            app.exportDisplayTraceData("Averages");
        end

        function traceTable = makeTraceTable(app, displayName, metadataRow, traceType, sweepIndex, timeMs, amplitudeUv) %#ok<INUSD>
            nPoints = numel(timeMs);
            traceTable = table( ...
                repmat(string(displayName), nPoints, 1), ...
                repmat(string(metadataRow.SessionLabel(1)), nPoints, 1), ...
                repmat(string(metadataRow.Protocol(1)), nPoints, 1), ...
                repmat(string(metadataRow.Eye(1)), nPoints, 1), ...
                repmat(metadataRow.RecordNumber(1), nPoints, 1), ...
                repmat(metadataRow.StepNumber(1), nPoints, 1), ...
                repmat(metadataRow.FlashDb(1), nPoints, 1), ...
                repmat(string(traceType), nPoints, 1), ...
                repmat(sweepIndex, nPoints, 1), ...
                (1:nPoints)', timeMs(:), amplitudeUv(:), ...
                'VariableNames', {'Display', 'SessionLabel', 'Protocol', 'Eye', 'RecordNumber', 'StepNumber', ...
                'FlashDb', 'TraceType', 'SweepIndex', 'PointIndex', 'TimeMs', 'AmplitudeUv'});
        end

        function appendLog(app, message)
            if isempty(app.ImportLogArea.Value)
                app.ImportLogArea.Value = {char(message)};
                return;
            end

            current = cellstr(app.ImportLogArea.Value);
            current{end + 1, 1} = char(message); %#ok<AGROW>
            app.ImportLogArea.Value = current;
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure("Visible", "off");
            app.UIFigure.Position = [100, 100, 1320, 820];
            app.UIFigure.Name = "ERG Analyzer";

            app.GridLayout = uigridlayout(app.UIFigure, [1, 1]);
            app.GridLayout.RowHeight = {"1x"};
            app.GridLayout.ColumnWidth = {"1x"};

            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            app.createImportTab();
            app.createRawTab();
            app.createAverageTab();
            app.createMeasuresTab();
            app.createExportTab();

            app.UIFigure.Visible = "on";
        end

        function createImportTab(app)
            app.ImportTab = uitab(app.TabGroup, "Title", "Import");
            grid = uigridlayout(app.ImportTab, [5, 3]);
            grid.RowHeight = {22, 32, "1x", "1x", "1x"};
            grid.ColumnWidth = {90, "1x", 120};
            grid.Padding = [12, 12, 12, 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            uilabel(grid, "Text", "Input File");
            app.FilePathField = uieditfield(grid, "text");
            app.FilePathField.Layout.Row = 1;
            app.FilePathField.Layout.Column = [2, 3];

            app.SelectFileButton = uibutton(grid, "push", "Text", "Browse...");
            app.SelectFileButton.Layout.Row = 2;
            app.SelectFileButton.Layout.Column = 2;
            app.SelectFileButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFileButtonPushed, true);

            app.ImportButton = uibutton(grid, "push", "Text", "Import File");
            app.ImportButton.Layout.Row = 2;
            app.ImportButton.Layout.Column = 3;
            app.ImportButton.ButtonPushedFcn = createCallbackFcn(app, @ImportButtonPushed, true);

            summaryLabel = uilabel(grid, "Text", "Session Summary");
            summaryLabel.Layout.Row = 3;
            summaryLabel.Layout.Column = [1, 2];

            logLabel = uilabel(grid, "Text", "Import Log");
            logLabel.Layout.Row = 3;
            logLabel.Layout.Column = 3;

            app.SummaryTextArea = uitextarea(grid, "Editable", "off");
            app.SummaryTextArea.Layout.Row = [4, 5];
            app.SummaryTextArea.Layout.Column = [1, 2];

            app.ImportLogArea = uitextarea(grid, "Editable", "off");
            app.ImportLogArea.Layout.Row = [4, 5];
            app.ImportLogArea.Layout.Column = 3;
        end

        function createRawTab(app)
            app.RawTab = uitab(app.TabGroup, "Title", "Raw Traces");
            grid = uigridlayout(app.RawTab, [3, 10]);
            grid.RowHeight = {32, "2x", "1x"};
            grid.ColumnWidth = {120, 130, 110, 110, 120, 130, 130, 140, 140, "1x"};
            grid.Padding = [12, 12, 12, 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            app.RawSessionDropDown = uidropdown(grid, "Items", {'All'});
            app.RawSessionDropDown.Layout.Row = 1;
            app.RawSessionDropDown.Layout.Column = 1;
            app.RawSessionDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshRawView, true);

            app.RawProtocolDropDown = uidropdown(grid, "Items", {'All'});
            app.RawProtocolDropDown.Layout.Row = 1;
            app.RawProtocolDropDown.Layout.Column = 2;
            app.RawProtocolDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshRawView, true);

            app.RawEyeDropDown = uidropdown(grid, "Items", {'All', 'R', 'L'});
            app.RawEyeDropDown.Layout.Row = 1;
            app.RawEyeDropDown.Layout.Column = 3;
            app.RawEyeDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshRawView, true);

            app.RawFlashDropDown = uidropdown(grid, "Items", {'All'});
            app.RawFlashDropDown.Layout.Row = 1;
            app.RawFlashDropDown.Layout.Column = 4;
            app.RawFlashDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshRawView, true);

            app.ShowExcludedCheckBox = uicheckbox(grid, "Text", "Show Excluded", "Value", true);
            app.ShowExcludedCheckBox.Layout.Row = 1;
            app.ShowExcludedCheckBox.Layout.Column = 5;
            app.ShowExcludedCheckBox.ValueChangedFcn = createCallbackFcn(app, @refreshRawView, true);

            app.ExcludeSelectedButton = uibutton(grid, "push", "Text", "Exclude Selected");
            app.ExcludeSelectedButton.Layout.Row = 1;
            app.ExcludeSelectedButton.Layout.Column = 6;
            app.ExcludeSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @ExcludeSelectedButtonPushed, true);

            app.IncludeSelectedButton = uibutton(grid, "push", "Text", "Include Selected");
            app.IncludeSelectedButton.Layout.Row = 1;
            app.IncludeSelectedButton.Layout.Column = 7;
            app.IncludeSelectedButton.ButtonPushedFcn = createCallbackFcn(app, @IncludeSelectedButtonPushed, true);

            app.RawExportFigureButton = uibutton(grid, "push", "Text", "Export .fig/.pdf");
            app.RawExportFigureButton.Layout.Row = 1;
            app.RawExportFigureButton.Layout.Column = 8;
            app.RawExportFigureButton.ButtonPushedFcn = createCallbackFcn(app, @RawExportFigureButtonPushed, true);

            app.RawExportTraceDataButton = uibutton(grid, "push", "Text", "Export Trace Data");
            app.RawExportTraceDataButton.Layout.Row = 1;
            app.RawExportTraceDataButton.Layout.Column = 9;
            app.RawExportTraceDataButton.ButtonPushedFcn = createCallbackFcn(app, @RawExportTraceDataButtonPushed, true);

            app.RawAxes = uiaxes(grid);
            app.RawAxes.Layout.Row = 2;
            app.RawAxes.Layout.Column = [1, 10];

            app.RawTable = uitable(grid);
            app.RawTable.Layout.Row = 3;
            app.RawTable.Layout.Column = [1, 10];
            app.RawTable.CellSelectionCallback = createCallbackFcn(app, @RawTableSelectionChanged, true);
        end

        function createAverageTab(app)
            app.AverageTab = uitab(app.TabGroup, "Title", "Averages");
            grid = uigridlayout(app.AverageTab, [3, 7]);
            grid.RowHeight = {32, "2x", "1x"};
            grid.ColumnWidth = {120, 140, 120, 140, 140, "1x", "1x"};
            grid.Padding = [12, 12, 12, 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            app.AvgSessionDropDown = uidropdown(grid, "Items", {'All'});
            app.AvgSessionDropDown.Layout.Row = 1;
            app.AvgSessionDropDown.Layout.Column = 1;
            app.AvgSessionDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshAverageView, true);

            app.AvgProtocolDropDown = uidropdown(grid, "Items", {'All'});
            app.AvgProtocolDropDown.Layout.Row = 1;
            app.AvgProtocolDropDown.Layout.Column = 2;
            app.AvgProtocolDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshAverageView, true);

            app.AvgEyeDropDown = uidropdown(grid, "Items", {'All', 'R', 'L'});
            app.AvgEyeDropDown.Layout.Row = 1;
            app.AvgEyeDropDown.Layout.Column = 3;
            app.AvgEyeDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshAverageView, true);

            app.AvgExportFigureButton = uibutton(grid, "push", "Text", "Export .fig/.pdf");
            app.AvgExportFigureButton.Layout.Row = 1;
            app.AvgExportFigureButton.Layout.Column = 4;
            app.AvgExportFigureButton.ButtonPushedFcn = createCallbackFcn(app, @AvgExportFigureButtonPushed, true);

            app.AvgExportTraceDataButton = uibutton(grid, "push", "Text", "Export Trace Data");
            app.AvgExportTraceDataButton.Layout.Row = 1;
            app.AvgExportTraceDataButton.Layout.Column = 5;
            app.AvgExportTraceDataButton.ButtonPushedFcn = createCallbackFcn(app, @AvgExportTraceDataButtonPushed, true);

            app.AverageAxes = uiaxes(grid);
            app.AverageAxes.Layout.Row = 2;
            app.AverageAxes.Layout.Column = [1, 7];

            app.AverageTable = uitable(grid);
            app.AverageTable.Layout.Row = 3;
            app.AverageTable.Layout.Column = [1, 7];
        end

        function createMeasuresTab(app)
            app.MeasuresTab = uitab(app.TabGroup, "Title", "Measures");
            grid = uigridlayout(app.MeasuresTab, [2, 1]);
            grid.RowHeight = {32, '1x'};
            grid.Padding = [12, 12, 12, 12];

            app.MeasuresSessionDropDown = uidropdown(grid, "Items", {'All'});
            app.MeasuresSessionDropDown.Layout.Row = 1;
            app.MeasuresSessionDropDown.Layout.Column = 1;
            app.MeasuresSessionDropDown.ValueChangedFcn = createCallbackFcn(app, @refreshMeasuresView, true);

            app.MeasuresTable = uitable(grid);
            app.MeasuresTable.Layout.Row = 2;
            app.MeasuresTable.Layout.Column = 1;
        end

        function createExportTab(app)
            app.ExportTab = uitab(app.TabGroup, "Title", "Export");
            grid = uigridlayout(app.ExportTab, [4, 4]);
            grid.RowHeight = {22, 32, "1x", "1x"};
            grid.ColumnWidth = {90, "1x", 120, 120};
            grid.Padding = [12, 12, 12, 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            uilabel(grid, "Text", "Output");

            app.ExportPathField = uieditfield(grid, "text");
            app.ExportPathField.Layout.Row = 1;
            app.ExportPathField.Layout.Column = [2, 4];

            app.BrowseExportButton = uibutton(grid, "push", "Text", "Browse...");
            app.BrowseExportButton.Layout.Row = 2;
            app.BrowseExportButton.Layout.Column = 2;
            app.BrowseExportButton.ButtonPushedFcn = createCallbackFcn(app, @BrowseExportButtonPushed, true);

            app.ExportButton = uibutton(grid, "push", "Text", "Export XLSX");
            app.ExportButton.Layout.Row = 2;
            app.ExportButton.Layout.Column = 3;
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportButtonPushed, true);

            app.SaveMatButton = uibutton(grid, "push", "Text", "Save MAT");
            app.SaveMatButton.Layout.Row = 2;
            app.SaveMatButton.Layout.Column = 4;
            app.SaveMatButton.ButtonPushedFcn = createCallbackFcn(app, @SaveMatButtonPushed, true);
        end
    end

    methods (Access = public)
        function app = ERGAnalyzerApp()
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end
end

function localDeleteFigure(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end

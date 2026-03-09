function exportSessionSummary(session, outFile, summaryTable, rawTable)
% exportSessionSummary Export current results to an Excel workbook.

arguments
    session (1, 1) struct
    outFile (1, :) char
    summaryTable table = table()
    rawTable table = table()
end

if ~isfield(session, "results") || ~isfield(session.results, "summaryTable")
    session = computeSessionResults(session);
end

if isempty(summaryTable)
    summaryTable = session.results.summaryTable;
end

if isempty(rawTable)
    rawTable = session.results.rawTable;
end

if isempty(summaryTable)
    error("ERG:NoResults", "No results available to export.");
end

writetable(summaryTable, outFile, 'Sheet', 'Measures');
writetable(rawTable, outFile, 'Sheet', 'Records');
end

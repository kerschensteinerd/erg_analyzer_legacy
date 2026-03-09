function schema = inspectLkcMdb(filePath)
% inspectLkcMdb Print the discovered MDB tables and columns.

if ~isfile(filePath)
    error("ERG:FileNotFound", "File not found: %s", filePath);
end

mdbData = readMdbTables(filePath);
schema = struct();
schema.Provider = mdbData.Provider;
schema.Tables = repmat(struct("Name", "", "Columns", strings(0, 1), "Height", 0), 1, numel(mdbData.Tables));

fprintf("MDB provider: %s\n", string(mdbData.Provider));
fprintf("Discovered %d user tables/views\n\n", numel(mdbData.Tables));

for idx = 1:numel(mdbData.Tables)
    tbl = mdbData.Tables(idx).Data;
    originalNames = string(tbl.Properties.VariableNames);
    if isstruct(tbl.Properties.UserData) && isfield(tbl.Properties.UserData, "OriginalVariableNames")
        originalNames = string(tbl.Properties.UserData.OriginalVariableNames);
    end

    schema.Tables(idx).Name = mdbData.Tables(idx).Name;
    schema.Tables(idx).Columns = originalNames(:);
    schema.Tables(idx).Height = height(tbl);

    fprintf("[%d] %s (%d rows)\n", idx, mdbData.Tables(idx).Name, height(tbl));
    for colIdx = 1:numel(originalNames)
        fprintf("    - %s\n", originalNames(colIdx));
    end
    fprintf("\n");
end
end

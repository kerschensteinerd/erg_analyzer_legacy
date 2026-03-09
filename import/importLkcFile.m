function session = importLkcFile(filePath)
% importLkcFile Dispatch import based on file extension.

arguments
    filePath (1, :) char
end

[~, ~, ext] = fileparts(filePath);
ext = lower(ext);

switch ext
    case ".mdb"
        session = importLkcMdb(filePath);
    case ".mat"
        session = loadSessionMat(filePath);
    otherwise
        error("ERG:UnsupportedFile", ...
            "Unsupported file type '%s'. Expected .mdb or .mat.", ext);
end
end

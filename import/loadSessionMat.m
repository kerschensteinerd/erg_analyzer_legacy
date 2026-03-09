function session = loadSessionMat(filePath)
% loadSessionMat Load a normalized ERG session saved as MAT.

arguments
    filePath (1, :) char
end

loaded = load(filePath);
fieldNames = string(fieldnames(loaded));

if any(fieldNames == "session")
    session = loaded.session;
    return;
end

error("ERG:InvalidMatFile", ...
    "MAT file must contain a variable named 'session': %s", filePath);
end

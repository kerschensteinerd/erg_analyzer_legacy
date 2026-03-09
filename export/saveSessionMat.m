function saveSessionMat(session, outFile)
% saveSessionMat Save a normalized ERG session for later reuse.

arguments
    session (1, 1) struct
    outFile (1, :) char
end

save(outFile, "session");
end

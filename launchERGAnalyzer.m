function app = launchERGAnalyzer()
% launchERGAnalyzer Add project folders to the MATLAB path and start the app.

launchTimer = tic;
setupErgAnalyzerPath();
launchContext = struct( ...
    "StartedAt", datetime("now"), ...
    "PathSetupSeconds", toc(launchTimer));
setappdata(0, 'ERGAnalyzerLaunchContext', launchContext);
app = ERGAnalyzerApp();
end

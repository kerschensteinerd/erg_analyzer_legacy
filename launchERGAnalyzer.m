function app = launchERGAnalyzer()
% launchERGAnalyzer Add project folders to the MATLAB path and start the app.

setupErgAnalyzerPath();
app = ERGAnalyzerApp();
end

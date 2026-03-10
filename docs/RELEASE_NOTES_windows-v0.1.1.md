# ERG Analyzer Windows v0.1.1

## Downloads

- Windows installer: `ERGAnalyzer-0.1.1-Windows-installer.zip`
- Windows standalone: `ERGAnalyzer-0.1.1-Windows-standalone.zip`

## Installation

1. Download the Windows installer ZIP
2. Unzip it
3. Run the installer
4. Allow MATLAB Runtime `R2025a` installation if prompted

## Highlights

- Improved packaged-app responsiveness on Windows by deferring heavy trace views until they are opened
- Faster packaged redraws for raw traces after filter changes and include/exclude edits
- Legacy LKC `.mdb` import validated on Windows with the bundled Java-8-compatible UCanAccess stack
- Raw traces, averages, and measures
- Session/mouse-based filtering
- Figure and trace-data export from the trace views

## Notes

- This Windows release is published separately from the existing macOS `v0.1.0` release.
- Windows SmartScreen may warn because the app is unsigned. Choose `More info`, then `Run anyway`, only if you trust the release source.
- This release is for end users without MATLAB.
- Source code remains available in the repository for maintainers and MATLAB users.
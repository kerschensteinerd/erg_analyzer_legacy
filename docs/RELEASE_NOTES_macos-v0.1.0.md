# ERG Analyzer macOS v0.1.0

## Downloads

- macOS installer: `ERGAnalyzer-0.1.0-macOS-installer.zip`
- macOS standalone: `ERGAnalyzer-0.1.0-macOS-standalone.zip`

## Installation

1. Download the macOS installer ZIP
2. Unzip it
3. Run the installer
4. Allow MATLAB Runtime `R2025a` installation if prompted

## Highlights

- Legacy LKC `.mdb` import
- Raw traces, averages, and measures
- Session/mouse-based filtering
- Figure and trace-data export from the trace views

## Notes

- This release is for end users without MATLAB.
- Source code remains available in the repository for maintainers and MATLAB users.
- The app is not yet code-signed. macOS may block the installer with a "damaged and can't be
  opened" error or an "unidentified developer" prompt. See the workaround below.

## macOS Gatekeeper workaround

macOS applies a quarantine flag to files downloaded from the internet. For unsigned apps this
causes a "damaged and can't be opened" error that cannot be dismissed through System Settings.

Open **Terminal** and run:

```
xattr -cr ~/Downloads/ERGAnalyzer-0.1.0-macOS-installer
```

Replace the path with the actual path to the unzipped installer folder on your machine, then
try running the installer again.

If macOS instead shows an "unidentified developer" prompt (rather than the "damaged" message),
open **System Settings > Privacy & Security**, allow the app to open, and retry.

If your institution's MDM policy disables the "Allow Anyway" button, the `xattr -cr` command
above still works. If Terminal is also blocked, contact your IT department or the maintainer.

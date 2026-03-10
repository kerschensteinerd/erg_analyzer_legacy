# ERG Analyzer v<version>

Use this template for a shared macOS + Windows GitHub release.

## Downloads

- macOS installer: `ERGAnalyzer-<version>-macOS-installer.zip`
- macOS standalone: `ERGAnalyzer-<version>-macOS-standalone.zip`
- Windows installer: `ERGAnalyzer-<version>-Windows-installer.zip`
- Windows standalone: `ERGAnalyzer-<version>-Windows-standalone.zip`

## Installation

1. Download the installer ZIP for your platform
2. Unzip it
3. Run the installer
4. Allow MATLAB Runtime installation if prompted

## Highlights

- Legacy LKC `.mdb` import
- Raw traces, averages, and measures
- Session/mouse-based filtering
- Figure and trace-data export from the trace views

## Notes

- This release is for end users without MATLAB
- Source code remains available in the repository for maintainers and MATLAB users
- **macOS**: See the workaround below if the installer shows "damaged and can't be opened"
- **Windows**: SmartScreen may warn because the app is unsigned — choose `More info`, then `Run anyway` only if you trust the release source

## macOS: Installer shows "damaged and can't be opened"

macOS applies a quarantine flag to files downloaded from the internet. For unsigned apps this
causes a "damaged and can't be opened" error that cannot be dismissed through System Settings.

Open **Terminal** and run:

```
xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer
```

Replace the path with the actual path to the unzipped installer folder on your machine, then
try running the installer again.

If macOS instead shows an "unidentified developer" prompt (rather than the "damaged" message),
open **System Settings > Privacy & Security**, allow the app to open, and retry.

If your institution's MDM policy disables the "Allow Anyway" button, the `xattr -cr` command
above still works. If Terminal is also blocked, contact your IT department or the maintainer.

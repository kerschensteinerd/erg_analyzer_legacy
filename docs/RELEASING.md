# Releasing ERG Analyzer

This project is distributed to non-MATLAB users through GitHub Releases.

## Prerequisites

- MATLAB installed on the build machine
- MATLAB Compiler licensed and available
- A clean copy of this repository
- Platform-native build machine:
  - macOS build on macOS
  - Windows build on Windows

## 1. Verify build environment

In MATLAB:

```matlab
cd('/path/to/erg')
setupErgAnalyzerPath
info = checkCompilerSetup();
```

Confirm:

- `CompilerAvailable = true`
- `PackageInstallerAvailable = true`
- MDB import dependency bundle is found

## 2. Set the release version

Update the top-level `VERSION` file before building.

## 3. Build the release

In MATLAB:

```matlab
cd('/path/to/erg')
setupErgAnalyzerPath
buildInfo = buildRelease();
```

Defaults:

- application name: `ERG Analyzer`
- executable name: `ERGAnalyzer`
- runtime delivery: web download
- outputs under `dist/<version>/<platform>/`

Main outputs:

- installer ZIP
- standalone ZIP
- `BUILD_INFO.txt`

## 4. Smoke test outside MATLAB

Test the packaged app on a machine without MATLAB installed if possible.

Minimum smoke test:

1. Launch the packaged app
2. Import a real `.mdb`
3. Check raw traces, averages, measures, and exports
4. Confirm `.xlsx`, `.mat`, `.fig`, and `.pdf` exports open

Use [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) as the sign-off sheet.

## 5. Publish GitHub Release

Create a tag matching the `VERSION` file, for example:

- `v0.1.0`

Upload at least:

- `ERGAnalyzer-<version>-macOS-installer.zip`
- `ERGAnalyzer-<version>-macOS-standalone.zip`
- `ERGAnalyzer-<version>-Windows-installer.zip`
- `ERGAnalyzer-<version>-Windows-standalone.zip`

Use [docs/RELEASE_TEMPLATE.md](docs/RELEASE_TEMPLATE.md) for the release body.

## Runtime delivery options

The build script defaults to:

- `RuntimeDelivery = "web"`

Use other options only when needed:

- `"installer"` for offline institutional installs
- `"none"` if users will install MATLAB Runtime separately

## Data hygiene before push

Do not commit:

- real animal `.mdb` files
- exported workbooks with study data
- legacy spreadsheets unless explicitly approved
- generated standalone or installer artifacts

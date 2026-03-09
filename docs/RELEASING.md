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

Choose the release shape that matches the build provenance:

- Shared cross-platform release: tag matches the `VERSION` file, for example `v0.1.0`
- Platform-specific release: tag identifies platform and version, for example `windows-v0.1.0`

Use a platform-specific tag when one platform is published from a different committed
source state than another platform release. Keep the top-level `VERSION` file at the
user-visible app version.

Do not attach artifacts from different committed source states to the same GitHub
release page.

For a shared cross-platform release, upload at least:

- `ERGAnalyzer-<version>-macOS-installer.zip`
- `ERGAnalyzer-<version>-macOS-standalone.zip`
- `ERGAnalyzer-<version>-Windows-installer.zip`
- `ERGAnalyzer-<version>-Windows-standalone.zip`

For a platform-specific release, upload only that platform's installer and standalone ZIPs.

Use [docs/RELEASE_TEMPLATE.md](docs/RELEASE_TEMPLATE.md) for a shared release body.
Use a platform-specific release-notes file when publishing a single-platform release, for
example [docs/RELEASE_NOTES_windows-v0.1.0.md](docs/RELEASE_NOTES_windows-v0.1.0.md).

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

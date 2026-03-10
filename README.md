# ERG Analyzer Legacy

MATLAB desktop application for importing and analyzing legacy LKC ERG `.mdb` files on modern macOS and Windows systems.

## For Lab Users

Do not download the source ZIP from the main GitHub page unless you plan to run the code inside MATLAB.

Use the latest GitHub Release instead:

1. Open the latest release on this repository.
2. Download the installer ZIP for your platform:
   - `ERGAnalyzer-<version>-macOS-installer.zip`
   - `ERGAnalyzer-<version>-Windows-installer.zip`
3. Unzip the download and run the installer inside it.
4. If prompted, allow the installer to download or install MATLAB Runtime.
5. Launch `ERG Analyzer`.
6. Import an LKC `.mdb` file or a previously saved `.mat` session.

Detailed end-user instructions are in [docs/INSTALL.md](docs/INSTALL.md).

Notes for packaged releases:
- First launch can still be slower because MATLAB Runtime has to start.
- First import of a new `.mdb` can be slower because the app builds a local cache for faster repeat imports.
- Unsigned macOS builds may need the Gatekeeper / `xattr` workaround documented in [docs/INSTALL.md](docs/INSTALL.md).

## For MATLAB Users

If you already have MATLAB and want to run from source:

```matlab
cd('/path/to/erg')
setupErgAnalyzerPath
launchERGAnalyzer
```

## What the App Does

- Imports legacy LKC `.mdb` files
- Imports saved normalized `.mat` sessions
- Displays raw sweeps and averaged traces
- Supports session/mouse-based filtering
- Computes summary ERG measures
- Exports measures, traces, figures, and `.mat` sessions

## Repository Layout

- `app/` UI code
- `analysis/` measurements and derived tables
- `import/` `.mdb` / `.mat` import logic
- `export/` workbook and session export logic
- `packaging/` MATLAB Compiler build scripts
- `docs/` end-user and maintainer documentation

## Maintainer Release Workflow

1. Verify MATLAB Compiler access with `checkCompilerSetup`.
2. Build a platform-specific release with `buildRelease`.
3. Smoke-test the packaged app outside MATLAB.
4. Upload installer and standalone ZIPs to a GitHub Release.

See [docs/RELEASING.md](docs/RELEASING.md) and [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

## Important Notes

- This repo is intended to stay source-only. End users should install from GitHub Releases.
- Sample `.mdb` files and legacy spreadsheets should not be pushed to a public repo unless they are explicitly approved for sharing.
- First release can be unsigned. Document macOS Gatekeeper and Windows SmartScreen prompts in the release notes.

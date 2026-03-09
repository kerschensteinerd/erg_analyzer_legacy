# Release Checklist

## Build inputs

- `VERSION` updated
- MATLAB release recorded
- MATLAB Compiler availability confirmed
- UCanAccess bundle present under `third_party/ucanaccess`
- No private `.mdb` or export files staged for commit

## macOS build

- Build completed without errors
- Installer ZIP created
- Standalone ZIP created
- Packaged app launches outside MATLAB
- Real `.mdb` import works
- Exported `.xlsx`, `.mat`, `.fig`, `.pdf` verified

## Windows build

- Build completed without errors
- Installer ZIP created
- Standalone ZIP created
- Packaged app launches outside MATLAB
- Real `.mdb` import works
- Exported `.xlsx`, `.mat`, `.fig`, `.pdf` verified

## GitHub Release

- Git tag matches the release shape (`v<version>` for shared releases, `<platform>-v<version>` for platform-specific releases)
- Uploaded assets were built from the tagged commit
- Release notes updated
- Shared release: macOS installer and standalone ZIPs uploaded
- Shared release: Windows installer and standalone ZIPs uploaded
- Platform-specific release: only that platform's installer and standalone ZIPs uploaded
- MATLAB Runtime requirement noted
- Known limitations noted
- Unsigned app warning documented if applicable

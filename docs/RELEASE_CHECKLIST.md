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

- Tag matches `VERSION`
- Release notes updated
- macOS installer ZIP uploaded
- macOS standalone ZIP uploaded
- Windows installer ZIP uploaded
- Windows standalone ZIP uploaded
- MATLAB Runtime requirement noted
- Known limitations noted
- Unsigned app warning documented if applicable

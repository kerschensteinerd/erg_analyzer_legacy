# MATLAB ERG Analyzer Quickstart

## Run the app

From MATLAB, change into the project folder and run:

```matlab
setupErgAnalyzerPath
launchERGAnalyzer
```

## Current state

The scaffold currently supports:

- launching a desktop ERG analysis app
- loading previously saved normalized MATLAB session files (`.mat`)
- importing legacy LKC `.mdb` files when a supported MDB provider is available
- reviewing raw traces
- including or excluding selected traces
- viewing averaged responses
- viewing computed summary measures
- exporting summary tables to Excel
- saving the current session as a MATLAB `.mat` file
- preparing standalone release builds for GitHub Releases

Provider requirements for `.mdb` import are documented in `IMPORTER_REQUIREMENTS.md`.

## Immediate development workflow

1. Run `launchERGAnalyzer`
2. Import an `.mdb` or normalized `.mat` file
3. Review the tabs and exclusion workflow
4. If testing a real LKC file, confirm that the required MDB provider is installed
5. Export a sample `.xlsx` or `.mat`

## Build a standalone release

For maintainers with MATLAB Compiler:

```matlab
setupErgAnalyzerPath
checkCompilerSetup
buildInfo = buildRelease();
```

This creates platform-specific standalone and installer ZIPs under `dist/<version>/<platform>/`.

If a real `.mdb` file does not import cleanly, run:

```matlab
checkMdbImportSetup
inspectLkcMdb('your_file.mdb')
```

The first command checks whether MATLAB can see an MDB provider. The second prints the discovered table and column names so the importer alias map can be extended quickly.

## Most important files

- `launchERGAnalyzer.m`
- `setupErgAnalyzerPath.m`
- `app/ERGAnalyzerApp.m`
- `analysis/computeSessionResults.m`
- `import/importLkcMdb.m`
- `packaging/checkCompilerSetup.m`
- `packaging/buildRelease.m`

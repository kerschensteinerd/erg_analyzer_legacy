# MATLAB App Designer ERG Modernization Plan

## Goal

Replace the legacy Excel/VBA plus Access-based LKC ERG workflow with a cross-platform MATLAB desktop application that runs on modern macOS and Windows systems.

The new application should:

- import LKC ERG data from legacy `.mdb` files
- reproduce the current analysis outputs used in the Excel workbook
- provide an interactive desktop GUI for trace review, exclusion, plotting, and export
- be distributable to lab users without requiring them to run legacy Excel macros

## Why MATLAB App Designer

MATLAB App Designer is a good fit when:

- the lab already uses MATLAB
- users are comfortable with MATLAB-style plots and tables
- desktop deployment is preferred over browser deployment
- the application needs a scientific UI rather than a spreadsheet UI

MathWorks supports packaging App Designer apps as standalone desktop applications with MATLAB Compiler, and end users can run them with MATLAB Runtime instead of a full MATLAB license.

## Recommended Technical Direction

Build the system in three layers:

1. Import layer
   - reads legacy `.mdb` files
   - converts raw recordings and metadata into MATLAB structs or tables
   - isolates all file-format-specific logic in one place

2. Analysis layer
   - computes averages, a-wave, b-wave, min/max timing, protocol summaries, exclusions, and exports
   - contains testable functions with no GUI code

3. GUI layer
   - App Designer desktop app
   - calls the analysis layer and renders plots, tables, and export tools

This separation is important because the `.mdb` import is the riskiest part of the migration. Once imported into a neutral MATLAB structure, the rest of the app becomes much easier to validate and maintain.

## Proposed User Workflow

1. Launch app
2. Select one `.mdb` file
3. App imports metadata and raw traces
4. App displays right-eye and left-eye recordings grouped by protocol and flash intensity
5. User reviews traces and optionally excludes selected recordings
6. App recomputes averages and derived measures
7. User inspects summary tables and plots
8. User exports results to Excel, CSV, MAT, and image/PDF outputs

## Proposed App Layout

Use a `uifigure`-based App Designer app with a tab group.

### Tab 1: Import

Purpose:
- select input file
- show file summary
- validate import

Controls:
- `Select MDB File` button
- recent files dropdown
- metadata panel for animal/date/source file
- import log text area
- `Run Import` button

Outputs:
- record count
- detected protocols
- right/left eye counts
- warnings for missing fields or unexpected schema

### Tab 2: Raw Traces

Purpose:
- inspect all imported traces before analysis

Controls:
- protocol dropdown
- eye selector
- record list
- show/hide accepted and excluded traces
- zoom/pan/reset buttons

Plots:
- stacked trace plot or overlay plot
- optional mean trace overlay

Table:
- record number
- step number
- eye
- flash dB
- background condition
- sampling rate
- inclusion flag

### Tab 3: Averaged Responses

Purpose:
- reproduce the workbook's averaged left/right sheets

Controls:
- protocol dropdown
- eye selector
- plot mode selector

Plots:
- averaged traces by intensity
- optional comparison overlays

Table:
- record set used in each average
- count of included traces
- flash intensity

### Tab 4: Measures

Purpose:
- reproduce `AvgMeasures` outputs from the workbook

Measures to display:
- a-wave amplitude
- b-wave amplitude
- minT
- maxT
- flash dB
- protocol
- eye
- record identifiers

Features:
- sortable table
- export selected rows
- optional tolerance comparison against legacy workbook results during validation phase

### Tab 5: Individual Review

Purpose:
- replace the workbook's individual graph sheets and exclusion workflow

Controls:
- next/previous record buttons
- include/exclude toggle
- notes field
- `Recompute` button

Plots:
- single-record trace
- current protocol average for comparison

### Tab 6: Export

Purpose:
- generate deliverables for downstream analysis and record keeping

Export formats:
- `.xlsx` summary workbook
- `.csv` tables
- `.mat` full session data
- `.png` or `.pdf` figures

Options:
- export all
- export current protocol
- export current plot

## Internal Data Model

Use a normalized MATLAB struct or table-based model rather than writing directly into spreadsheet-like arrays.

Suggested top-level structure:

```matlab
session.sourceFile
session.subject
session.testDate
session.records
session.protocols
session.analysisSettings
session.results
```

Suggested per-record fields:

```matlab
record.recordNumber
record.eye
record.protocol
record.flashDb
record.backgroundDb
record.sampleRate
record.samplesPerWave
record.timeMs
record.waveformUv
record.isIncluded
record.notes
```

This allows the GUI to filter and recompute results without depending on fixed Excel sheet coordinates.

## Import Strategy for Legacy MDB Files

This is the first technical milestone and likely the highest-risk part.

The sample `.mdb` appears to contain:

- metadata fields such as protocol, flash intensity, background, sampling rate, cursor settings, and patient fields
- waveform arrays for left and right eye traces

Recommended strategy:

1. Build a MATLAB import function around one known `.mdb` schema.
2. Confirm which tables/fields are always present across several historical files.
3. Convert imported data immediately into the internal MATLAB structure.
4. Save an intermediate `.mat` file after import so analysis/debugging can proceed without re-reading the `.mdb`.

If direct `.mdb` access in MATLAB becomes unreliable on macOS, use one of these fallback strategies:

- a small helper conversion step on Windows that converts `.mdb` to `.mat` or `.csv`
- a Python helper importer called from MATLAB
- an external MDB-to-text export utility run before app import

The GUI should not care which importer path was used, as long as the internal session structure is the same.

## Validation Strategy

The new app should be validated against the legacy workbook before deployment.

Validation steps:

1. Choose 5 to 10 representative historical `.mdb` files.
2. Run the legacy Excel workflow and save reference outputs.
3. Run the MATLAB importer and analysis.
4. Compare:
   - a-wave amplitudes
   - b-wave amplitudes
   - minT and maxT
   - included/excluded record sets
   - plotted average traces
5. Define acceptable tolerances for floating-point differences.
6. Document any intentional differences from the legacy workbook.

## Sharing the App with the Lab

There are two MATLAB-native sharing models.

### Model A: Users Have MATLAB

Package the app as a MATLAB app installation file (`.mlappinstall`).

Pros:
- simplest if users already have MATLAB
- updates are easy

Cons:
- every user needs MATLAB
- version mismatches may matter

### Model B: Users Do Not Need MATLAB

Package the app as a standalone desktop application using MATLAB Compiler.

Pros:
- users do not need a MATLAB license
- works better as a real lab tool

Cons:
- users must install MATLAB Runtime
- separate builds are needed for macOS and Windows

Recommended default for the lab:

- use standalone builds for most users
- keep a source version for developers and power users with MATLAB

## Installation Model for Lab Users

### Windows

1. Provide the packaged installer from MATLAB Compiler.
2. Install MATLAB Runtime if not already present.
3. Launch the app from the Start menu or desktop shortcut.

### macOS

1. Provide the packaged macOS application.
2. Install MATLAB Runtime for the matching MATLAB release.
3. Launch the app.
4. If the app is unsigned during early development, users may need to approve it through macOS security settings.

Institutionally, the easiest support model is:

- keep the installer and runtime instructions on a shared drive
- version releases explicitly
- maintain one Windows build and one macOS build per app release

## Suggested Project Structure

```text
erg-matlab/
  app/
    ERGAnalyzerApp.mlapp
  import/
    importLkcMdb.m
    parseLkcMetadata.m
    parseLkcWaveforms.m
  analysis/
    computeAvgResponses.m
    computeErgMeasures.m
    computeTimingMeasures.m
    applyInclusionMask.m
  export/
    exportSummaryWorkbook.m
    exportCsvTables.m
    exportFigures.m
  validation/
    compareAgainstLegacyWorkbook.m
    fixtures/
  docs/
    field_mapping.md
    validation_notes.md
```

## Recommended Build Order

### Phase 1: Reverse Engineer the Legacy Workflow

- document workbook outputs and calculations
- map `.mdb` fields to workbook sheets
- identify any protocol-specific special cases

### Phase 2: Build Importer

- ingest one `.mdb`
- reconstruct right/left traces and metadata
- save a normalized `.mat` session file

### Phase 3: Build Analysis Functions

- compute averages
- compute a-wave and b-wave metrics
- match legacy workbook outputs

### Phase 4: Build GUI

- import tab
- raw trace review
- averaged responses
- measures table
- exclusion workflow
- export tools

### Phase 5: Validate and Package

- compare against legacy outputs
- package Windows and macOS builds
- test with 2 to 3 lab users

## Minimum Viable Version

The first usable version does not need every feature from the Excel workbook.

Minimum viable scope:

- import one `.mdb`
- display left/right raw traces
- compute averaged responses
- compute and display a-wave, b-wave, minT, maxT
- allow inclusion/exclusion of traces
- export summary tables to `.xlsx`

Leave advanced graph customization and rare protocol edge cases for later versions.

## Main Risks

1. Legacy `.mdb` schema may vary across years or instruments.
2. Some calculations in the workbook may be embedded in VBA assumptions rather than explicit formulas.
3. Direct `.mdb` reading may be less reliable on macOS than Windows.
4. Packaging and security prompts on macOS may require extra institutional support.

## Recommendation

Proceed with a MATLAB App Designer implementation, but start with importer and analysis functions before building much GUI.

The app should aim to preserve the current scientific workflow while dropping the spreadsheet-based implementation. The migration should prioritize:

- reproducible import
- validated measures
- simple desktop deployment

Only after those are stable should effort go into polishing the interface.

# LKC MDB Import Requirements

The MATLAB ERG app can now import legacy `.mdb` files through one of two database-access paths.

## Option 1: Windows MATLAB with Access drivers

Recommended when lab users run MATLAB on Windows.

Requirements:

- MATLAB on Windows
- Microsoft Access Database Engine / ACE OLEDB provider installed

The importer will try these providers in order:

- `Microsoft.ACE.OLEDB.16.0`
- `Microsoft.ACE.OLEDB.12.0`
- `Microsoft.Jet.OLEDB.4.0`

## Option 2: UCanAccess JDBC on any platform

Recommended when users need direct `.mdb` import on macOS.

Requirements:

- MATLAB with Java enabled
- UCanAccess jar set available in one of these locations:
  - `third_party/ucanaccess/`
  - `lib/ucanaccess/`
  - directory pointed to by `UCANACCESS_HOME`

The jar directory should contain the main UCanAccess jar plus its dependency jars.

## Current parser behavior

The importer looks for:

- metadata in a table like `Patient Information`
- waveform samples either:
  - directly in `Data` or `MultiData` columns, or
  - in long-form tables/queries with `Record#` plus a value column like `LVAL`

On macOS/Linux with UCanAccess, temporary HSQLDB mirror files are now redirected into a dedicated folder under the system temp directory instead of being created next to the `.mdb` files. The importer also attempts to remove newly created `UCanAccess_*` temp folders after the import finishes.

It maps the database into the normalized session model used by the app:

- record number
- eye
- step number
- protocol
- flash intensity
- background intensity
- sample rate
- number of samples
- waveform values
- inclusion flag

## Known limitations

- The importer was implemented against reverse-engineered schema clues from the legacy workbook and sample `.mdb`, but it has not been runtime-tested in this environment because MATLAB and MDB drivers are not available here.
- Historical LKC databases may vary slightly in schema across instrument generations.
- If a specific `.mdb` layout does not import cleanly, the next step is to inspect that file's actual table/column names and extend the alias map in `import/importLkcMdb.m`.

# Install ERG Analyzer from GitHub Releases

These instructions are for lab users who do not use MATLAB.

## 1. Download the app

1. Open the latest release for `erg_analyzer_legacy`.
2. Download the installer ZIP for your computer:
   - macOS: `ERGAnalyzer-<version>-macOS-installer.zip`
   - Windows: `ERGAnalyzer-<version>-Windows-installer.zip`
3. Unzip the file.

## 2. Run the installer

1. Open the unzipped folder.
2. Run the installer inside it.
3. If the installer asks to download MATLAB Runtime, allow it.

If your institution does not allow web downloads during install, ask the maintainer for a release built with bundled MATLAB Runtime or for separate MATLAB Runtime install instructions.

## 3. Launch the app

After installation, open `ERG Analyzer`.

The app may still feel slower the first time it launches because MATLAB Runtime has to start. Opening the app again should be faster.

## 4. Open your data

1. Click `Browse...`
2. Choose an LKC `.mdb` file or a saved `.mat` session
3. Click `Import File`

The first import of a new `.mdb` may take longer while the app builds a local cache. Re-importing the same unchanged file should be much faster.

## 5. Export results

- Use the `Measures` and `Export` tabs for summary tables
- Use the `Raw Traces` and `Averages` tabs to export current trace views and trace data

## Troubleshooting

### macOS says the installer is damaged and can't be opened

macOS applies a quarantine flag to files downloaded from the internet. For
unsigned apps this causes a "damaged and can't be opened" error that cannot be
dismissed through System Settings.

Open **Terminal** and run:

```
xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer
```

Replace the path with the actual path to the unzipped installer folder or
`.app` bundle on your machine, then try running the installer again.

### macOS says the app cannot be opened (unidentified developer)

If macOS shows a different prompt about an unidentified developer rather than
the "damaged" message, open:

`System Settings > Privacy & Security`

Then allow the app to open and retry.

### My institution only allows applications from the App Store & Known Developers

Institutional macOS systems managed by MDM may lock Gatekeeper so that the
"Allow Anyway" button in System Settings is disabled or absent.

The underlying cause is the same as the "damaged" error: macOS has flagged the
downloaded file with a quarantine attribute. Removing that attribute before
running the installer prevents Gatekeeper from blocking it:

```
xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer
```

Replace the path with the actual path to the unzipped installer folder on your
machine, then try running the installer again.

If your IT policy prevents running Terminal commands, ask your IT department to
whitelist the application or contact the maintainer for a code-signed build.

If Terminal reports `Permission denied`, retry with `sudo`:

```bash
sudo xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer
```

You can also run the same commands against the unzipped `.app` bundle instead
of the installer folder, for example:

```bash
xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer.app
sudo xattr -cr ~/Downloads/ERGAnalyzer-<version>-macOS-installer.app
```

If you are not sure about the path, drag the installer folder or `.app` from
Finder into the Terminal window after `xattr -cr ` or `sudo xattr -cr ` and
macOS will paste the exact path.

### Windows shows a SmartScreen warning

If the release is unsigned, choose `More info` and then `Run anyway` only if you trust the release source.

### MDB import fails

Report the exact file name and error message to the maintainer. The packaged release should include the MDB import dependency bundle automatically.

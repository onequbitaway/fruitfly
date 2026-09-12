# Build and release

## Build

Run `make build` on a Mac. The script builds the app for your Mac type.
Run `make release` to build one app for Apple Silicon and Intel Macs.
The script writes the app and a ZIP file to `dist`.

The project uses Swift and Apple frameworks. It has no package dependencies.

## Release

1. Update `VERSION`.
2. Update `docs/release-notes.md`.
3. Check the app on a Mac.
4. Commit the changes.
5. Create a version tag, such as `v0.1.0`.
6. Push the tag to GitHub.

GitHub builds the app and adds the ZIP file to a public release.
The release includes a SHA-256 checksum. Use it to check the downloaded file.

## Apple approval

Local builds use an ad hoc signature. This signature checks file integrity.
It does not identify an Apple-approved developer.

Downloads do not yet have Apple approval through notarization.
macOS may block the first start. Follow [Apple's instructions](https://support.apple.com/en-us/102445) for apps from other sources.
Do not turn off Gatekeeper or other Mac security controls.

## Writing

Follow [ASD-STE100](https://www.asd-ste100.org/about_STE.html) principles.
Use short sentences and active voice. Keep each instruction in a separate sentence.
Use common words where possible. Define a technical term when readers need it.

# Build and release

## Build

Run `make build` on a Mac. The script builds the app for your Mac type.
Run `make release` to build one app for Apple Silicon and Intel Macs.
The script writes the app and a ZIP file to `dist`.

The project uses Swift and Apple frameworks. It has no package dependencies.

## Check

Run `make test` to check food, movement, screen limits, and the brain model.
These checks use a small Swift program. They do not require the full Xcode app.

Run the app check after a build:

```sh
dist/Fruitfly.app/Contents/MacOS/Fruitfly --smoke-test
```

This check opens the app briefly. It checks food placement, click handling, the data, and hiding.
It uses events inside the app. It does not click another app.

To render a preview of the app's own controls, run:

```sh
dist/Fruitfly.app/Contents/MacOS/Fruitfly --render-preview /tmp/fruitfly-preview.png
```

## Check by hand

- Open the app from Applications.
- Use Place food. Make sure the click does not reach the app below.
- Press Esc during food placement. Make sure normal clicks work again.
- Hold Option and double-click. Make sure one crumb appears.
- Pause the fly. Make sure food does not disappear during the pause.
- Hide the fly. Make sure the food is also hidden.
- Check the app with dark and light appearance settings.
- Check another display, a full-screen app, and a Space change.
- Disconnect the display that contains the fly. Make sure the fly moves to a visible display.

Full-screen apps can cover floating windows on some macOS versions.
The overlay does not read other window contents or attach the fly to their borders.

## Release

1. Update `VERSION`.
2. Update `docs/release-notes.md`.
3. Check the app on a Mac.
4. Commit the changes.
5. Create a version tag, such as `v0.1.0`.
6. Push the tag to GitHub.

GitHub builds the app and adds the ZIP file to a public release.
The release includes a SHA-256 checksum. Use it to check the downloaded file.

Put the ZIP and checksum files in the same folder. Run this command from that folder:

```sh
shasum -a 256 -c Fruitfly-0.1.0-macos-universal.zip.sha256
```

Change the version in the filename for a later release.

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

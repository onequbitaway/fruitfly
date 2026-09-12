# Fruitfly

A small pet fly for your Mac desktop.

The fly will move across your screen. Hold Option and double-click to drop food.
Your other apps will receive normal clicks.

**Status:** Initial setup. The app shell builds and runs. The desktop fly is the next step.

## Requirements

- macOS 14 or later.
- An Apple Silicon or Intel Mac.

Windows and Linux are not supported.

## Build and start the app

1. Install the Apple build tools:

   ```sh
   xcode-select --install
   ```

2. Download the source:

   ```sh
   git clone https://github.com/onequbitaway/fruitfly.git
   cd fruitfly
   ```

3. Build and start the app:

   ```sh
   make run
   ```

The build creates `dist/Fruitfly.app`. You can move this file to Applications.
Click Fruitfly in the menu bar to quit.

## Downloads

The first release is not available yet.
Each release will include one app for both Mac types.
Users will not need the build tools to run a release.

## Brain map

The project will use data from the [MaleCNS brain map](https://male-cns.janelia.org/).
The map records connections between nerve cells. It does not define all fly behavior.
The app will explain which movements come from the model and which movements come from animation rules.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you change the code.
See [docs/development.md](docs/development.md) for build and release steps.

## License

The app code uses the [MIT license](LICENSE).
Brain data retains its own license. See [docs/data.md](docs/data.md).

Run the full-map prototype and inspect the code used for the animations.

The preview includes both Simple (3,745 cells) and Full map (166,700 cells).
The full graph has 25,582,938 directed connections. Both modes run in the preview window.
The download contains the data and works without Python, an account, or a separate service.

Download **Fruitfly-Full-Map-Preview-0.1.0-macos-universal.zip**.
Extract it, then move **Fruitfly Preview** to Applications.
The app supports macOS 14 or later on Apple Silicon and Intel Macs.
Metal is used when available. A CPU fallback runs the same model.
This preview is not notarized. See the README for Apple's Open Anyway instructions.

The release also includes:

- The prepared MaleCNS data pack for source builds.
- The desktop MP4 and the desktop-to-brain MP4 for sharing.
- The animation evidence archive, with saved rates, trace files, stills, and check results.
- SHA-256 checksums for each download.

All model and recording source is in `experiments/full-map`.
Use `make preview` from a fresh clone to build and run it.
The data pack stays in Releases so the repository remains easy to clone.

This is an experimental model of the mapped brain and nerve cord.
It is not a complete working animal. Movement follows pet rules.
Food use in Full map reads the MN9 feeding output.
The desktop video uses a staged scene. The full-map app runs in its own window.
The stable desktop pet remains available as v0.2.0.

Data: MaleCNS v1.0, HHMI Janelia FlyEM, University of Cambridge,
MRC Laboratory of Molecular Biology, and Google Research. License: CC BY 4.0.
Cell equations and parameters follow Shiu et al. (2024), with the differences documented in the model notes.

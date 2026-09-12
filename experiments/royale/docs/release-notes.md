# Fruitfly Royale 0.1.0

Ten flies. One survivor.

Download **Fruitfly-Royale-0.1.0-macos-universal.zip**. Open the ZIP, then
open **Fruitfly Royale.app**. Use macOS 14 or later on Apple Silicon or Intel.
The app includes both data sets and works offline. It needs no account.

Ten flies start around a dish. Four crumbs draw them into fights. Hits
cause damage, knockback, and red blood particles. The ring closes until
one fly remains. Double-click to drop food. Click a fly to see its brain.
Use the controls to pause, restart, change mode, or turn blood effects off.

- **Simple:** 3,745 cells per fly. Uses less memory.
- **Full map:** 166,700 cells per fly. May run slower than real time.

Each fly has its own calculated brain state. The game waits for each model
step. Combat, movement, healing, health, and blood are game rules. They
are not measured or learned fly behavior. Red blood is a fictional effect.

The MP4 and GIF show a Full map round at three times model time. The trace
records per-fly brain activity, input, position, health, hits, and winner.
All app and animation source is in `experiments/royale`.

This app uses an ad-hoc code signature and is not notarized by Apple.
If macOS blocks the download, use **System Settings → Privacy & Security →
Open Anyway** after the first launch attempt, if you trust the source.
You can also build it with `make royale`.

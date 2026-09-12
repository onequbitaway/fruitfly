Two flies fight on a leaf stage. Watch jumps, shields, throws, and ring-outs.

- Choose Simple (3,745 cells per fly) or Full map (166,700 cells per fly).
- Each fly has a separate brain state. The two plots show calculated activity.
- Cell rates affect movement and attack timing. Combat follows programmed rules. The flies have not learned to fight.
- Three lives per fly. A 90-second match limit. Tied lives start sudden death.
- Optional red blood particles follow hit events.

Combat uses the MIT-licensed [Super Bash Folds](https://github.com/blancmathis/Super_Bash_Folds) engine. Fruitfly supplies the fly art, stage, and brain connection.

Download `Fruitfly-Duel-0.1.0-macos-universal.zip`. Open the ZIP, then open Fruitfly Duel. The download includes both data sets. It works offline on Intel and Apple Silicon Macs with macOS 14 or later. Full map may run below real time.

This is an experimental, ad-hoc signed app. It is not notarized. macOS may require **System Settings → Privacy & Security → Open Anyway** after the first launch attempt.

Press Space to pause, R for a new match, and B to switch blood effects. The app runs in its own window. It needs no account, screen access, Node, or Python.

The attached Full map replay uses seed 42. It plays at three times model time. The trace archive includes all recorded brain samples, game frames, plotted rates, inputs, control values, and rate hashes. All source and recording code is public.

[Source and build instructions](https://github.com/onequbitaway/fruitfly/tree/main/experiments/duel)

Validation: 20 complete seeded game tests; both brain modes; exact plotted cell rates; independent states; silent-brain controls; packaged app checks. All 714 recorded brain samples reproduce the saved combat frames. The recorded match contains 21 hits and five ring-outs.

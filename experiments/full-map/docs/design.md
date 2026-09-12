# Local preview design

Purpose: compare the small smell network with the full mapped network. Show which recorded cell classes respond to each input. Make experimental limits visible.

Palette: deep blue #0B1524 for the map; slate #16273A for controls; pale blue #E3F0FC for text; cyan #40D6D6 for smell; amber #FFAD6B for taste; violet #AB9CF5 for central-complex cells. Other classes retain distinct subdued colors.

Type: the Mac system font. Rounded 25-point title, 13-point controls, 11-point data labels. Use plain sentence case.

Layout: one large map using published cell-body coordinates. Put the guided fly trial and inputs on the left. Put actual cell-class spike counts and named output cells on the right. Keep all controls left-aligned. Put time traces below the map. Show cells without coordinates separately and label that area.

Review: avoid a generic dashboard of cards. The real brain shape is the main element. Do not label a class as an active behavior. Never change brightness from the trial stage. Use a fixed spike-rate scale. A silent output must stay at zero.

Full map means graph coverage. The cell model, sensory encoding, and guided desktop movement are experimental choices. It does not mean a validated complete animal simulation.

## Preview review

Checked native renders at 1260 × 820 for the food trial, the direct feeding test, and Simple mode. Fixed the input-button spacing and made the trace scale cover the observed class means. The real brain silhouette is the main element. The nerve cord is separate and labeled. Classes without cells in Simple stay empty. Missing cell positions are counted in the caption. No neuron has an invented location.

The first anatomy renderer created one huge path and stalled. The final renderer draws individual points and caches the static anatomy. Activity uses the current spike rates. Both modes, pause, reset, food placement while paused, direct feeding, and the MN9 block passed live controller checks.

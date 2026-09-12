# Fruitfly Duel

Two flies fight on three leaves above a pond. The match fills the window.

- Pond blue #D8F0F3; sky #F1FAFC; leaf green #388768; deep blue #164459; red #D74443; violet #6850B9.
- Avenir Next Heavy for the game title and damage. Avenir Next Medium for controls and notes. System font fallback.
- Two clear sides. Pip sits left; Zip sits right. Damage and three life dots stay near each fly’s brain map below the stage.
- One large stage, three leaf platforms, detailed fly bodies, translucent wings, attack arcs, short red hit particles. Effects come from combat events.
- Brain dots use real cell positions and calculated rates. The footer explains the game rules.

```
Fruitfly Duel                          Pause / New match / Simple / Full map
                      two flies on three leaves
          lower leaf         high leaf         lower leaf
                  large main leaf above a pond
Pip   0%   •••    brain map             brain map   •••   0%   Zip
```

Review before build: Use a pond and leaf stage, not a generic neon arena. Keep decorative scenery faint so hit effects and flies remain easy to see. Do not use stock dashboard cards. Use native Mac controls.

## Visual review

The native window was inspected in Full map and Simple modes, including a larger window. The leaf tops match the collision surfaces. Both flies and both brain maps remain visible. Damage, life dots, and mode controls are legible. The stage has room for aerial moves. Pause and mode changes work. Keep the pale scenery; do not add dashboard panels.

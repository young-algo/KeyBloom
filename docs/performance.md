# Renderer performance protocol

The stress surface renders the production background and the maximum 84 live blooms on every simulated display. It exists to make frame-cost comparisons repeatable without entering Baby Mode or locking the Mac.

Run both traces on the oldest supported Mac:

```bash
./scripts/profile_renderer.sh 1 15
./scripts/profile_renderer.sh 2 15
```

The profiler requires full Xcode because Apple does not include `xctrace` or the SwiftUI/Core Animation Instruments templates with Command Line Tools alone.

Open the resulting traces under `tmp/profiles/` in Instruments and inspect:

- sustained frame time against the 16.6 ms target;
- time in `BloomRenderer.draw`, label resolution, and effect drawing;
- the one-display versus two-display delta;
- whether 84 active blooms materially differs from a lower ceiling such as 48.

Do not lower the secondary-display frame rate or the burst ceiling without measurements from the slowest target Mac. If the two-display trace exceeds budget while the one-display trace does not, pass a primary-display flag into `GameView` and use a lower `TimelineView` refresh rate only for non-primary kiosk windows.

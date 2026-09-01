# KeyBloom App Icon Design Philosophy

## Core Identity & Emotional Resonance

KeyBloom is a native macOS playground for toddlers where every keyboard press triggers joyful visual responses—blooming flowers, stars, rings, and confetti. 

The app icon captures this core interaction with maximum clarity and Dock-scale legibility: a tactile keyboard keycap with a vivid flower burst emerging directly from its top surface.

## Visual Design Principles (Revised for Aggressive Dock Legibility)

### 1. Palette & High Silhouette Contrast
- **Background Tile**: Deep navy-to-purple rounded tile (`#201648` to `#090518`) matching macOS Big Sur+ squircle proportions.
- **High-Contrast Keycap**: Sculpted slate-periwinkle keycap (`#7A70A6` top dish to `#463B70` base) maintaining >2.5:1 face-to-background contrast and highlighted by a crisp specular rim stroke (`#C0CEFF`).
- **Luminous Upper Bloom**: 5–7 broad petals in electric cyan/turquoise (`#00F2FE` to `#0088FF`), hot neon magenta (`#FF0844`), and solar yellow (`#FFD200`).

### 2. Form & Composition
- **Uncovered Key Face**: The keycap is positioned in the lower half of the tile (Y=140 to Y=420) so its top dish face remains clearly visible and recognizable.
- **Upper-Hemisphere Bloom**: Broad petals burst upward from the top dish of the key (Y=420 to Y=810), with at most two short flanking side petals, eliminating clutter below the key line.
- **Zero Detail Clutter**: Free of shockwave rings, comet arcs, sparkle dots, confetti, or petal spine strokes. Focuses entirely on strong, iconic shapes that remain unmistakable at 16×16 and 32×32 pixels.

### 3. Execution & Build Pipeline
- Deterministic vector rendering using macOS `CoreGraphics` / `AppKit`.
- Image caching for duplicate pixel dimensions (32px, 256px, 512px, 1024px).
- Automatic iconset cleanup before and after `.icns` conversion.

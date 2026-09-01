# KeyBloom App Icon Design

## Goal

Give KeyBloom a distinctive macOS app icon that communicates both keyboard interaction and colorful visual blooms, remains recognizable at Dock size, and persists across rebuilds.

## Visual Design

- Use a macOS-style rounded-square composition with a deep navy-to-purple background.
- Center one large, softly shaded keyboard key as the primary silhouette.
- Place a vivid cyan, pink, and yellow flower-like burst emerging from the key.
- Use no lettering or fine detail that becomes illegible at small sizes.
- Keep strong contrast between the background, key, and bloom.

## Integration

- Store the source icon artwork in the KeyBloom project.
- Generate a complete macOS `.icns` file with standard icon sizes.
- Update `build_app.sh` and the generated `Info.plist` so installed builds include and declare the icon.
- Rebuild and reinstall `~/Applications/KeyBloom.app` using the existing build workflow.

## Dock Cleanup

- Remove every existing KeyBloom item from `com.apple.dock` persistent apps.
- Add exactly one entry pointing to `~/Applications/KeyBloom.app`.
- Restart the Dock and refresh relevant icon registration/cache state if needed.

## Verification

- Confirm the installed bundle declares its icon and contains the `.icns` resource.
- Confirm the `.icns` file includes multiple resolutions.
- Confirm Dock preferences contain exactly one KeyBloom app entry.
- Confirm macOS resolves the installed application icon rather than the generic app icon.

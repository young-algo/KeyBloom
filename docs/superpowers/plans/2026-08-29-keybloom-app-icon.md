# KeyBloom App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give KeyBloom a persistent, recognizable key-and-bloom macOS icon and leave exactly one working Dock entry.

**Architecture:** Generate the icon deterministically from a Swift/AppKit drawing script, package a standard multi-resolution `AppIcon.icns` resource into every app build, and declare it through `CFBundleIconFile`. Rebuild the signed app, remove all stale KeyBloom Dock tiles, then insert one canonical tile and refresh Launch Services/Dock state.

**Tech Stack:** Swift, AppKit/Core Graphics, `iconutil`, zsh, macOS `defaults`, Launch Services

## Global Constraints

- Support macOS 14 or later.
- Use a rounded-square deep navy/purple background, a large keyboard key, and a vivid cyan/pink/yellow flower burst.
- Use no text or fine detail that becomes illegible at Dock size.
- Preserve the existing code-signing behavior in `build_app.sh`.
- This directory has no Git repository, so commit steps do not apply.

---

### Task 1: Deterministic Icon Asset

**Files:**
- Create: `scripts/generate_app_icon.swift`
- Create: `Assets/AppIcon.icns`

**Interfaces:**
- Consumes: macOS AppKit drawing APIs and `iconutil`.
- Produces: `Assets/AppIcon.icns`, containing 16, 32, 128, 256, 512, and 1024-pixel representations.

- [ ] **Step 1: Create the vector-style drawing script**

Implement `scripts/generate_app_icon.swift` so it draws a 1024×1024 transparent canvas with: a rounded navy-to-purple squircle inset from the canvas edge; a centered, softly shaded keycap with a strong silhouette; and a cyan/pink/yellow petal burst emerging above the key. The script must render each standard iconset filename (`icon_16x16.png` through `icon_512x512@2x.png`) directly at its target pixel dimensions, then run `iconutil -c icns` to produce `Assets/AppIcon.icns`.

- [ ] **Step 2: Generate the icon**

Run:

```bash
swift scripts/generate_app_icon.swift
```

Expected: exit status 0 and `Assets/AppIcon.icns` exists.

- [ ] **Step 3: Validate the icon container**

Run:

```bash
rm -rf /tmp/keybloom-icon.iconset
iconutil -c iconset Assets/AppIcon.icns -o /tmp/keybloom-icon.iconset
test -f /tmp/keybloom-icon.iconset/icon_16x16.png
test -f /tmp/keybloom-icon.iconset/icon_512x512@2x.png
```

Expected: all commands exit with status 0.

### Task 2: Bundle Integration

**Files:**
- Modify: `build_app.sh:28-73`

**Interfaces:**
- Consumes: `Assets/AppIcon.icns` from Task 1.
- Produces: an app bundle containing `Contents/Resources/AppIcon.icns` and declaring `CFBundleIconFile=AppIcon`.

- [ ] **Step 1: Add an asset precondition and resource copy**

Before signing, make `build_app.sh` fail with a clear message if `$ROOT_DIR/Assets/AppIcon.icns` is absent. Copy that file to `$APP_BUNDLE/Contents/Resources/AppIcon.icns` after creating the Resources directory.

- [ ] **Step 2: Declare the bundle icon**

Add these exact keys to the generated `Info.plist` dictionary:

```xml
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
```

- [ ] **Step 3: Build and install**

Run:

```bash
./build_app.sh --install
```

Expected: build, signing, and installation complete without errors.

- [ ] **Step 4: Validate the installed bundle**

Run:

```bash
test -f "$HOME/Applications/KeyBloom.app/Contents/Resources/AppIcon.icns"
test "$(defaults read "$HOME/Applications/KeyBloom.app/Contents/Info" CFBundleIconFile)" = "AppIcon"
codesign --verify --deep --strict "$HOME/Applications/KeyBloom.app"
```

Expected: all commands exit with status 0.

### Task 3: Dock Deduplication and Cache Refresh

**Files:**
- No project files modified.

**Interfaces:**
- Consumes: installed `~/Applications/KeyBloom.app` from Task 2.
- Produces: one persistent Dock tile referencing the canonical installed app.

- [ ] **Step 1: Remove all KeyBloom persistent app tiles safely**

Read the current `persistent-apps` plist, filter out every tile whose file URL resolves to `~/Applications/KeyBloom.app`, and write the filtered array back without changing unrelated Dock items.

- [ ] **Step 2: Add one canonical Dock tile**

Append one `file-tile` whose `_CFURLString` is `file://$HOME/Applications/KeyBloom.app` and whose `_CFURLStringType` is `15`.

- [ ] **Step 3: Refresh application registration and Dock**

Run Launch Services registration for the installed app, touch the app bundle, and restart the Dock with `killall Dock`.

- [ ] **Step 4: Verify exact Dock cardinality and icon metadata**

Inspect `defaults read com.apple.dock persistent-apps` and confirm exactly one tile URL contains `/Applications/KeyBloom.app`. Confirm `mdls -name kMDItemCFBundleIdentifier -name kMDItemFSName "$HOME/Applications/KeyBloom.app"` reports `com.kevinturner.keybloom` and `KeyBloom.app`.

- [ ] **Step 5: Visual verification**

Confirm the single KeyBloom Dock tile shows the key-and-bloom artwork rather than the generic application icon. If Dock still shows stale artwork, restart `iconservicesagent` and Dock once, then verify again.

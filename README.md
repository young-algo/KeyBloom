# KeyBloom

KeyBloom is a native macOS keyboard playground for a baby or toddler. Every key press creates a large, colorful bloom at roughly the matching part of the keyboard. Multi-key mashing triggers a larger celebration. Nothing is typed into a text field, stored, or sent anywhere.

## Behavior

- Borderless full-screen windows cover every connected display.
- Random keys create bubbles, flowers, stars, comets, rings, pinwheels, and occasional confetti.
- Holding a key produces a rate-limited stream instead of overwhelming the renderer.
- Three or more simultaneous keys create a larger “chord” celebration.
- Mouse and trackpad clicks create ripples; scrolling creates arrows and comets.
- The cursor is hidden during play.
- Motion is deliberately smooth, with no full-screen flashes or rapid strobing.
- Sound is omitted by design.

## Lock modes

### Strong lock — recommended

Strong lock uses a macOS event tap while Baby Mode is active. It captures keyboard and pointer input before system shortcuts can switch applications. macOS requires a one-time Accessibility permission because this mode can suppress input events.

The event tap exists only while Baby Mode is running. KeyBloom does not record key history, write keystrokes to disk, use the network, or monitor input while the setup window is open.

### Standard lock

Standard lock needs no special permission. It uses an app-local event monitor plus macOS presentation options to hide the Dock and menu bar and disable ordinary application switching. Some macOS-reserved shortcuts or gestures may still take precedence.

## Adult exit

Hold these five keys together for 1.5 seconds:

**Control + Option + Shift + Command + Delete**

Backslash (`\`) is accepted in place of Delete. Order does not matter — the countdown starts as soon as all five are down, and releasing any one of them cancels it. A small progress ring appears in the top-right corner while the hold is in progress.

**Emergency exit:** Command + Option + Escape exits immediately. The Mac's physical power controls remain a final fallback.

### Why not Escape?

Escape cannot be used as part of the four-modifier chord. Once Command and Option are held, macOS routes Escape to its own Force Quit handler, and the key event is never delivered to KeyBloom — the app cannot see a key the system has already consumed. Delete and Backslash have no system binding under those modifiers, so they reach the app reliably.

## Troubleshooting

### Accessibility permission is granted but Strong lock still says it is missing

macOS ties an Accessibility grant to the app's code signature. If the app is ad-hoc signed, the grant is pinned to the exact binary hash and every rebuild silently invalidates it, even though System Settings still shows the checkbox as enabled.

`build_app.sh` signs with a stable code-signing identity to avoid this. It picks one automatically, or you can choose one explicitly:

```bash
KEYBLOOM_SIGN_IDENTITY="Your Code Signing Certificate" ./build_app.sh --install
```

If no identity is available the script falls back to ad-hoc signing and warns you. To create one, use Keychain Access → Certificate Assistant → Create a Certificate, with type **Code Signing**.

After changing the signing identity, clear the stale grant and re-approve:

```bash
tccutil reset Accessibility com.kevinturner.keybloom
```

### Diagnosing input problems

Launch with logging enabled to record every key event the app actually receives:

```bash
KEYBLOOM_DEBUG=1 ~/Applications/KeyBloom.app/Contents/MacOS/KeyBloom
```

Events are appended to `~/Library/Logs/KeyBloom.log`. This is the fastest way to tell whether a key is being handled incorrectly or is never reaching the app at all.

## Build and install

Requirements:

- macOS 14 or later
- Apple Command Line Tools or Xcode

From Terminal:

```bash
cd /path/to/KeyBloom
./build_app.sh --install
```

This builds a release app, installs it at `~/Applications/KeyBloom.app`, and opens it.

If `swift` is unavailable:

```bash
xcode-select --install
```

You can also build without installing:

```bash
./build_app.sh
open "dist/KeyBloom.app"
```

## First launch with Strong lock

1. Open KeyBloom.
2. Leave **Strong lock** enabled and select **Grant Permission**.
3. In System Settings, enable KeyBloom under **Privacy & Security → Accessibility**.
4. Return to KeyBloom and press **Start Baby Mode**.

After rebuilding the executable, macOS may ask you to re-enable the Accessibility permission. Installing at the same `~/Applications/KeyBloom.app` path keeps the workflow predictable.

## Easy customizations

Edit `Sources/KeyBloom/AppConfig.swift` to change:

- Exit hold duration
- Maximum active bursts
- Key-repeat visual rate
- Visual lifetime

Edit `Sources/KeyBloom/GameModel.swift` to change how keys select effects. Edit `Sources/KeyBloom/GameView.swift` to change the rendering.

## Safety boundaries

KeyBloom intentionally does not try to override the login window, Touch ID, physical power controls, kernel-level shortcuts, or other macOS security surfaces. Those are appropriate emergency boundaries. Use the app with adult supervision and keep the computer stable, dry, and clear of reachable cables.

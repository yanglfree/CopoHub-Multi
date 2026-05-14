# HarmonyOS 2-in-1 Flutter-OH Surface Lifecycle Fix

## Summary

CopoHub hit a white-screen issue on HarmonyOS 2-in-1 devices in PC/windowed mode. The Dart application was already running and building the expected pages, but the Flutter-OH native surface did not become the visible first frame.

The final fix is to keep Dart startup at the FlutterAbility lifecycle timing, disable automatic early engine attachment, and explicitly attach the Flutter engine after ArkUI creates the XComponent surface. The fix also synchronizes the Flutter viewport and native XComponent buffer size from the window drawable rect.

## Symptoms

- The app window opens with a white content area.
- Dart logs show normal startup:
  - `runApp.after`
  - `CopoHubApp.firstBuild`
  - `Router.build.login`
  - `LoginPage.build`
- A small native ArkUI probe can render on top of the white area, proving ArkUI is alive.
- `FlutterView.hasRenderedFirstFrame()` remains false even after Dart's first post-frame callback.
- Native logs show repeated surface or buffer recreation around the Flutter XComponent.

## Root Cause

This is not a CopoHub Dart UI failure. It is a Flutter-OH embedding lifecycle issue exposed by HarmonyOS 2-in-1 windowed mode.

The problematic sequence was:

1. `FlutterView` is created before the ArkUI XComponent native surface is ready.
2. Flutter-OH automatically attaches the engine too early.
3. The native side enters a preload or stale surface path.
4. Dart continues to run and builds widgets, but the engine is not attached to the visible XComponent surface.
5. First-frame state in `FlutterView` can remain stale because native `isDisplayingFlutterUi` changes are not pushed back into the ArkTS `FlutterView` state.

On 2-in-1 devices, decorated windows add another complication: `windowRect` and `drawableRect` can diverge because the title bar is outside the app drawable area. Sizing Flutter from the wrong rect causes incorrect rendering or input mapping.

## Final Solution

### EntryAbility

`EntryAbility` now owns the timing of the Flutter surface attachment:

- Override `provideFlutterEngine` to create and initialize the engine early.
- Override `attachToEngineAutomatically()` and return `false`.
- Let Dart start from the FlutterAbility lifecycle, but do not attach the engine to XComponent until the surface exists.
- Listen for a `flutterSurfaceCreated` event emitted from `FlutterPage` XComponent `onLoad`.
- Retry attachment at short intervals because ArkUI surface and window drawable rect can settle over several frames.
- Sync viewport from `drawableRect` when available, falling back to `windowRect`.
- Call `preDraw(width, height)` using the same drawable rect.

### Flutter-OH patch

The project patches the local Flutter-OH package during the Harmony build:

- `FlutterAbility.ets`
  - Starts Dart from `onCreate`.
  - Keeps XComponent attachment controlled by `EntryAbility.attachToEngineAutomatically()`.
- `FlutterPage.ets`
  - Emits `flutterSurfaceCreated` from XComponent `onLoad`.
- `FlutterView.ets`
  - Adds `ensureSurfaceAttached()`.
  - Re-attaches native XComponent when the surface becomes available.
  - Synchronizes first-frame state from native `FlutterNapi`.

The patch is tracked in:

```text
flutter/ohos/patches/flutter_ohos_2in1_surface_lifecycle.patch
```

`flutter/ohos/hvigorfile.ts` applies this patch automatically to:

```text
flutter/ohos/oh_modules/@ohos/flutter_ohos
```

This matters because `oh_modules` is ignored by Git and direct edits there would otherwise be lost.

## Excluded Causes

### Dart application startup

Excluded because logs showed `runApp.after`, app first build, route build, and login page build all completing normally.

### Authentication or routing logic

Excluded because both logged-out routing and `LoginPage.build` executed as expected.

### Login page layout

Excluded because the same white screen persisted while native ArkUI probes rendered above the Flutter content area.

### API cache or service initialization

Excluded because startup services completed, and later route/page logs appeared after them.

### General HarmonyOS process failure

Excluded because the app process stayed alive, window events arrived, ArkUI page lifecycle callbacks fired, and native overlay/probe UI rendered.

### Full-screen permission rejection as the only cause

Partially related but not sufficient. Swallowing `setWindowLayoutFullScreen` failures prevents startup hangs, but does not by itself attach Flutter to the correct XComponent surface.

## Validation

Validation performed:

- Harmony build passed with:

```bash
hvigorw assembleHap --no-daemon
```

- The Flutter-OH patch was tested for idempotent build-time application.
- The final HAP was installed on a HarmonyOS 2-in-1 device.
- Device screenshot confirmed that Flutter UI rendered correctly instead of white-screening.

## Follow-up Risk

After the white-screen fix, full-screen or maximized windows exposed a coordinate mapping problem: clicking a visible point `A` could hit logical point `B`.

The cause was a second Flutter-OH embedding mismatch. In maximized 2-in-1 mode, Dart kept the original viewport size, for example `2091x1324`, while ArkUI resized the XComponent to the larger drawable area, for example `3120x1885`. With `RenderFit.RESIZE_FILL`, XComponent visually stretched the old Flutter buffer to the new size, but native input events were still delivered in the unstretched coordinate space.

The final workaround is:

- Use `RenderFit.TOP_LEFT` for `FlutterPage` so XComponent itself does not stretch the Flutter buffer.
- Disable XComponent frame cache for this page because the surface is expected to resize in 2-in-1 windows.
- Keep the FlutterPage at its first measured size.
- Apply an outer ArkUI scale transform from the current page area divided by the first measured area.
- Anchor the scaled node at `Alignment.TopStart` and `centerX/centerY = 0vp`.

This makes the visual transform and ArkUI hit testing use the same coordinate transform. Validation confirmed that a click on the scaled bottom navigation item is transformed back to the original Flutter coordinate and hits the expected tab.

When debugging similar input issues, treat rendering and hit-testing as two separate pipelines:

- Rendering path: XComponent attach, `preDraw`, native buffer size, first-frame state.
- Input path: XComponent native coordinates, density, viewport metrics, platform view coordinate conversion, window/drawable origin.

Prefer a true viewport update when Flutter-OH accepts it. If the engine keeps the old Dart viewport after window resize, avoid `RESIZE_FILL` and move the scaling to ArkUI so hit testing follows the same transform as rendering.

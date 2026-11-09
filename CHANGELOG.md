## 0.3.1

* Fix: the whole-grid PNG is now composed from per-device captures, so
  devices scrolled off screen are included and nothing is clipped. Rows are
  labelled with the variant, devices with name and size, offending devices
  outlined in red.
* Fix: when every device is replaced at once (for example switching variants
  on), the new devices open on the page the old ones were on.

## 0.3.0

* Overflow and error report: every `FlutterError` (RenderFlex overflow,
  exceptions in build/layout/paint) is traced back to the device and variant
  it happened on, by walking from the failing render object / element up to
  the device. The device gets a red outline and a badge with the count.
* Issues panel (toolbar ⚠ button) listing device · variant, the message and
  how many times it happened; `controller.issues`, `issuesFor(slotId)`,
  `clearIssues()` for tests and CI.
* PNG export: the whole grid, or every device at its real resolution
  (device pixel ratio). Saved to `responsive_mirror_exports/` on desktop, the
  temp directory on mobile, downloaded on the web, or handed to `onExport`.
  Also `controller.exportPng(perDevice: true)`.
* The original `FlutterError.onError` is still called and is restored when
  the mirror is disposed.

## 0.2.0

* Variants: render the same screen in several locales and themes side by side,
  as a matrix (devices × variants). `MirrorVariant.english`, `.arabic`,
  `.light`, `.dark`, `.largeText`, `MirrorVariant.locale(...)`,
  `MirrorVariant.theme(...)`, `combine()` and `MirrorVariant.matrix(...)`.
* RTL languages get `TextDirection.rtl` automatically.
* Theme variants override `MediaQuery.platformBrightness`, so apps using
  `ThemeMode.system` switch with no code change.
* `ResponsiveMirror.localeOf(context)` / `ResponsiveMirror.themeModeOf(context)`
  for `MaterialApp.locale` / `MaterialApp.themeMode`.
* Toolbar chips to show / hide variants; labelled rows per variant.
* Fit now wraps devices into rows and uses the available height; the canvas is
  centred; the zoom label no longer lags one frame.

## 0.1.0

* `ResponsiveMirror(child: MyApp())` renders your app on several devices at once,
  side by side, in a zoomable, scrollable grid.
* Device presets: iPhone 15, iPhone SE, Pixel 8, iPad Air, Laptop 1366×768,
  Laptop 1440×900, Desktop 1920×1080, plus `MirrorDevice.custom(...)`.
* Each device gets its own `MediaQuery` (size, devicePixelRatio, safe area,
  text scale) and its own `Navigator`.
* Navigation sync: push / pop / replace / remove on one device is replayed on
  the others (`ResponsiveMirror.navigatorObserverOf(context)`).
* Scroll sync: scrolling a list on one device moves the matching list on the
  others to the same scroll fraction (0..1), matched by `ValueKey` or position.
* Toolbar: toggle devices, sync on/off, zoom (buttons, Ctrl/⌘ + wheel, Fit),
  show the app once full size.
* Debug-only by default (`enabled: kDebugMode`); returns your app untouched
  in release builds.

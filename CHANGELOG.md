## 0.4.1

* Isolated mode: PNG export works. A frame is a separate page, so the host
  asks every agent to capture its own screen (`RepaintBoundary.toImage`)
  and send the PNG back over `postMessage`; per-device exports and the grid
  sheet are built from those. `MirrorRelay.capture(slotId, pixelRatio)`.
* Docs: limitations found while running a real production GetX app in the
  mirror: one global navigator key (use isolated mode), shared web storage
  between frames, tap targets across languages need a `ValueKey`, and
  Chrome's WebGL context limit (keep isolated mode to about 6–8 devices).

## 0.4.0

* Isolated mode (`mode: MirrorMode.isolated`, **Flutter web only**): every
  device runs as its own instance of your web build, in an iframe, with its
  own state. The frame loads the same page with `?rm_frame=…`;
  `ResponsiveMirror` notices it is inside a frame and wraps your app in a
  `ResponsiveMirrorAgent` instead of drawing the grid, so no code change is
  needed beyond the `mode` flag.
* The agent records taps, text input and scrolling and the host relays them
  (`postMessage`) to the other devices, which replay them on the matching
  widget. Targets are matched by `ValueKey`, then semantics label / tooltip /
  input label, then visible text, then position among identical candidates —
  never by coordinates, because every device has its own layout.
* A device where the target does not exist (for example a desktop-only side
  panel) is marked **out of sync** with the reason; the next action that
  matches clears it. Taps on fields are not replayed (that would steal the
  keyboard in a browser); their text is mirrored instead.
* Errors inside a frame are reported to the host and show up on the device
  badge and in the issues panel, like in-process mode.
* On other platforms `MirrorMode.isolated` falls back to in-process mode with
  a debug message. Why: separate instances of a Flutter desktop app need
  separate engines/windows, which a widget inside one app cannot embed today;
  the web has iframes.
* Fix: device labels never widen a tile, so badges no longer re-flow the grid.

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

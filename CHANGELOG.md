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

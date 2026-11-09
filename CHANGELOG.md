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

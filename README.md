# responsive_mirror

See your Flutter app on a phone, a tablet, a laptop and a desktop **at the same
time**, with navigation and scrolling kept in sync.

```dart
void main() => runApp(ResponsiveMirror(child: MyApp()));
```

It is a plain widget, so it runs wherever Flutter runs: Windows, Linux, macOS
and the web.

Show the same screen in Arabic (RTL) and English, dark and light, at once:

```dart
ResponsiveMirror(
  variants: MirrorVariant.matrix(
    [MirrorVariant.english, MirrorVariant.arabic],
    [MirrorVariant.light, MirrorVariant.dark],
  ),
  child: MyApp(),
)
```

Overflows are traced back to the device (and language/theme) they happen on,
with a red badge and a list. Export the whole grid, or every device, as PNG.

> Work in progress. See CHANGELOG.md.

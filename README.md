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

On the web you can also run every device as a **separate instance** of your
app (own state, one iframe each). Taps, typing and scrolling are replayed on
the other devices, matched by key / label / text, and a device that has no
matching widget is marked "out of sync":

```dart
ResponsiveMirror(mode: MirrorMode.isolated, child: MyApp())
```

> Work in progress. See CHANGELOG.md.

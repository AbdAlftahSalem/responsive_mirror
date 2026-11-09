# responsive_mirror example

A small shop app (list/grid, product page, add-product form) mirrored on a
phone, a tablet, a 1366 laptop and a 1920 desktop.

```bash
cd example
flutter run -d chrome     # or -d windows / -d linux / -d macos
```

The cart badge is app state that lives outside `MaterialApp`, so tapping
"Add to cart" on one device updates every device. Navigation and scrolling
are mirrored by `responsive_mirror`.

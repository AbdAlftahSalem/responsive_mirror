import 'package:flutter/material.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'shop_app.dart';

/// Variants offered in the toolbar. They start hidden; tap a chip (or open
/// the page with `?variants=1`) to see English · Light next to Arabic · Dark.
final List<MirrorVariant> demoVariants = [
  MirrorVariant.english.combine(MirrorVariant.light),
  MirrorVariant.arabic.combine(MirrorVariant.dark),
  MirrorVariant.arabic.combine(MirrorVariant.light),
  MirrorVariant.english.combine(MirrorVariant.dark),
];

void main() {
  final query = Uri.base.queryParameters;
  final controller = ResponsiveMirrorController(
    devices: MirrorDevices.defaults,
    variants: demoVariants,
    visibleVariantIds: query['variants'] == '1'
        ? [demoVariants[0].id, demoVariants[1].id]
        : const [],
  );
  runApp(
    // One line: every device below runs its own copy of ShopApp.
    // `enabled: true` keeps the mirror on in release web builds of this demo;
    // in your app you can leave the default (debug only).
    ResponsiveMirror(
      enabled: true,
      controller: controller,
      // Web only: `?mode=isolated` runs every device as its own instance of
      // this web build (one iframe each, separate state); taps, text and
      // scrolling are replayed between them.
      mode: query['mode'] == 'isolated'
          ? MirrorMode.isolated
          : MirrorMode.inProcess,
      child: const ShopApp(),
    ),
  );
}

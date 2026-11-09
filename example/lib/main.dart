import 'package:flutter/material.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'shop_app.dart';

void main() {
  runApp(
    // One line: every device below runs its own copy of ShopApp.
    // `enabled: true` keeps the mirror on in release web builds of this demo;
    // in your app you can leave the default (debug only).
    const ResponsiveMirror(
      enabled: true,
      child: ShopApp(),
    ),
  );
}

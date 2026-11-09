import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders one copy per device with that device\'s MediaQuery',
      (tester) async {
    useLargeWindow(tester);
    final seen = <String, MediaQueryData>{};

    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      builder: (context, slot) => MaterialApp(
        home: Builder(builder: (context) {
          seen[slot!.device.id] = MediaQuery.of(context);
          return Text('hello ${slot.device.id}');
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(seen.keys, unorderedEquals(MirrorDevices.defaults.map((d) => d.id)));
    for (final device in MirrorDevices.defaults) {
      final data = seen[device.id]!;
      expect(data.size, device.size, reason: device.name);
      expect(data.devicePixelRatio, device.devicePixelRatio);
      expect(data.padding, device.safeArea);
      expect(find.text('hello ${device.id}'), findsOneWidget);
    }
  });

  testWidgets('custom devices and toggling a device off', (tester) async {
    useLargeWindow(tester);
    final watch =
        MirrorDevice.custom(name: 'Watch', size: const Size(198, 242));
    final controller = ResponsiveMirrorController(
      devices: [MirrorDevices.iPhone15, watch, MirrorDevices.desktop],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(home: Text('app')),
    ));
    expect(find.text('app'), findsNWidgets(3));
    expect(watch.id, 'watch');

    controller.toggleDevice(watch);
    await tester.pump();
    expect(find.text('app'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('rm_device_chip_watch')));
    await tester.pump();
    expect(find.text('app'), findsNWidgets(3));
  });

  testWidgets('disabled mirror returns the app untouched', (tester) async {
    MirrorSlot? slot = MirrorSlot(
      id: 'x',
      device: MirrorDevices.iPhone15,
      navigatorObserver: NavigatorObserver(),
    );
    await tester.pumpWidget(ResponsiveMirror(
      enabled: false,
      builder: (context, s) {
        slot = s;
        return const MaterialApp(home: Text('plain'));
      },
    ));
    expect(find.text('plain'), findsOneWidget);
    expect(slot, isNull);
    expect(find.byType(MirrorDeviceFrame), findsNothing);
  });

  testWidgets('zoom buttons change the scale, Fit resets it', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(zoom: 0.3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(home: SizedBox()),
    ));
    await tester.tap(find.byKey(const ValueKey('rm_zoom_in')));
    await tester.pump();
    expect(controller.zoom, closeTo(0.375, 1e-9));
    await tester.tap(find.byKey(const ValueKey('rm_zoom_fit')));
    await tester.pump();
    expect(controller.zoom, isNull);
    expect(defaultTargetPlatform, isNotNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'helpers.dart';

/// A banner that only fits on wide screens: it overflows on phones.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      Icon(Icons.local_shipping),
      SizedBox(width: 520, child: Text('Free shipping on every order')),
    ]);
  }
}

void main() {
  testWidgets('overflow is attributed to the device it happened on',
      (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [
        MirrorDevices.iPhoneSE,
        MirrorDevices.iPadAir,
        MirrorDevices.laptop,
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(
        home: Scaffold(body: SafeArea(child: PromoBanner())),
      ),
    ));
    await tester.pumpAndSettle();
    // The test framework also sees the overflow error; consume it.
    expect(tester.takeException(), isA<FlutterError>());

    expect(controller.issues, hasLength(1));
    final issue = controller.issues.single;
    expect(issue.slotId, 'iphone_se');
    expect(issue.kind, MirrorIssueKind.overflow);
    expect(issue.message, contains('overflowed'));
    expect(controller.issuesFor('laptop_1366'), isEmpty);

    // A red badge appears on the offending device only.
    expect(
        find.byKey(const ValueKey('rm_issue_badge_iphone_se')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('rm_issue_badge_laptop_1366')), findsNothing);

    // The panel lists it.
    await tester.tap(find.byKey(const ValueKey('rm_issues')));
    await tester.pump();
    expect(find.byKey(const ValueKey('rm_issues_panel')), findsOneWidget);
    expect(find.textContaining('iPhone SE'), findsWidgets);

    controller.clearIssues();
    await tester.pump();
    expect(
        find.byKey(const ValueKey('rm_issue_badge_iphone_se')), findsNothing);
  });

  testWidgets('overflow in a variant row names the variant', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhoneSE],
      variants: const [MirrorVariant.english, MirrorVariant.largeText],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      builder: (context, slot) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: Row(children: [
                // Fits at 1.0, overflows at 1.5x text.
                Text('Checkout now', style: TextStyle(fontSize: 14)),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(controller.issues.map((i) => i.slotId), ['text150/iphone_se']);
    expect(controller.issues.single.where, 'iPhone SE · Text 150%');
  });

  testWidgets('errors outside the devices are not reported', (tester) async {
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(home: Text('ok')),
    ));
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('somewhere else'),
    ));
    tester.takeException();
    await tester.pump();
    expect(controller.issues, isEmpty);
  });

  testWidgets('the error handler is restored when the mirror goes away',
      (tester) async {
    final before = FlutterError.onError;
    await tester.pumpWidget(const ResponsiveMirror(
      enabled: true,
      child: MaterialApp(home: Text('ok')),
    ));
    expect(FlutterError.onError, isNot(before));
    await tester.pumpWidget(const SizedBox());
    expect(FlutterError.onError, before);
  });

  testWidgets('exports the grid and every device as PNG', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(home: Scaffold(body: Text('shot'))),
    ));
    await tester.pumpAndSettle();

    final perDevice =
        await tester.runAsync(() => controller.exportPng(perDevice: true));
    expect(perDevice!.map((e) => e.slotId),
        unorderedEquals(['iphone_15', 'laptop_1366']));
    for (final e in perDevice) {
      // PNG signature.
      expect(e.bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(e.fileName, endsWith('.png'));
    }
    final grid = await tester.runAsync(() => controller.exportPng());
    expect(grid!.single.slotId, isNull);
    expect(grid.single.fileName, 'responsive_mirror_grid.png');
  });
}

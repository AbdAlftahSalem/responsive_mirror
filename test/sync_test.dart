import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'helpers.dart';

Widget _app({ResponsiveMirrorController? controller}) {
  return ResponsiveMirror(
    enabled: true,
    controller: controller,
    devices: const [
      MirrorDevices.iPhone15,
      MirrorDevices.iPadAir,
      MirrorDevices.laptop,
    ],
    builder: (context, slot) => MaterialApp(
      navigatorObservers: [ResponsiveMirror.navigatorObserverOf(context)],
      routes: {
        '/settings': (_) => const Scaffold(body: Text('Settings page')),
      },
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: ListView.builder(
          key: const ValueKey('item_list'),
          itemCount: items.length,
          itemBuilder: (context, i) => ListTile(
            key: ValueKey('tile_$i'),
            title: Text(items[i]),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DetailsPage(title: items[i]),
            )),
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            key: const ValueKey('settings_fab'),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            child: const Icon(Icons.settings),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('push on one device is replayed on the others, pop too',
      (tester) async {
    useLargeWindow(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('tile_2')).first);
    await tester.pumpAndSettle();
    expect(find.text('Details Item 2'), findsNWidgets(3));

    // Back on the last device: every device pops.
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Details Item 2'), findsNothing);
    expect(find.text('Home'), findsNWidgets(3));

    // Named routes are replayed too.
    await tester.tap(find.byKey(const ValueKey('settings_fab')).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsNWidgets(3));
  });

  testWidgets('navigation sync can be switched off', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
      syncNavigation: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_1')).first);
    await tester.pumpAndSettle();
    expect(find.text('Details Item 1'), findsOneWidget);
  });

  testWidgets('a device turned back on catches up with the others',
      (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller: controller));
    await tester.pumpAndSettle();
    controller.setVisible(MirrorDevices.laptop, false);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_3')).first);
    await tester.pumpAndSettle();
    expect(find.text('Details Item 3'), findsOneWidget);

    controller.setVisible(MirrorDevices.laptop, true);
    await tester.pumpAndSettle();
    expect(find.text('Details Item 3'), findsNWidgets(2));
  });

  testWidgets('scrolling one device scrolls the others to the same fraction',
      (tester) async {
    useLargeWindow(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final lists = find.byKey(const ValueKey('item_list'));
    expect(lists, findsNWidgets(3));
    await tester.drag(lists.first, const Offset(0, -300));
    await tester.pumpAndSettle();

    final positions = tester
        .stateList<ScrollableState>(
            find.descendant(of: lists, matching: find.byType(Scrollable)))
        .map((s) => s.position)
        .toList();
    expect(positions, hasLength(3));
    expect(positions.first.pixels, greaterThan(0));
    final fractions = positions.map(ScrollMatcher.fractionOf).toList();
    for (final f in fractions.skip(1)) {
      expect(f, closeTo(fractions.first, 0.01));
    }
  });

  testWidgets('scroll sync can be switched off', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
      syncScroll: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller: controller));
    await tester.pumpAndSettle();
    final lists = find.byKey(const ValueKey('item_list'));
    await tester.drag(lists.first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final positions = tester
        .stateList<ScrollableState>(
            find.descendant(of: lists, matching: find.byType(Scrollable)))
        .map((s) => s.position.pixels)
        .toList();
    expect(positions.first, greaterThan(0));
    expect(positions.last, 0);
  });
}

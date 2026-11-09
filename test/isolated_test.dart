import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

/// Each copy has its OWN state (a StatefulWidget counter), like two separate
/// app instances in isolated mode.
class CounterApp extends StatefulWidget {
  const CounterApp({super.key});

  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int count = 0;
  final TextEditingController name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        final wide = MediaQuery.sizeOf(context).width > 600;
        return Scaffold(
          appBar: AppBar(title: Text('count: $count')),
          body: Column(children: [
            ElevatedButton(
              key: const ValueKey('inc'),
              onPressed: () => setState(() => count++),
              child: const Text('Add'),
            ),
            if (wide)
              TextButton(
                onPressed: () {},
                child: const Text('Wide only'),
              ),
            TextField(
              key: const ValueKey('name'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('list'),
                itemCount: 80,
                itemBuilder: (context, i) {
                  void open() => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text('Opened $i')),
                          ),
                        ),
                      );
                  // Different widgets per layout, same key: matched by key.
                  if (!wide) {
                    return ListTile(
                      key: ValueKey('row_$i'),
                      leading: const Icon(Icons.star),
                      title: Text('Row $i'),
                      subtitle: const Text('phone layout'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: open,
                    );
                  }
                  return Card(
                    key: ValueKey('row_$i'),
                    child: InkWell(
                      onTap: open,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Row $i  (desktop card)'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      }),
    );
  }
}

MirrorSlot _slot(String id, Size size) => MirrorSlot(
      id: id,
      device: MirrorDevice.custom(name: id, size: size),
      navigatorObserver: NavigatorObserver(),
    );

Future<LocalMirrorHub> _pumpPair(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final hub = LocalMirrorHub();
  Widget copy(String id, Size size) => SizedBox(
        width: size.width,
        height: size.height,
        child: ResponsiveMirrorAgent(
          slot: _slot(id, size),
          channel: hub.channelFor(id),
          child: const CounterApp(),
        ),
      );
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      copy('phone', const Size(400, 760)),
      copy('desktop', const Size(900, 760)),
    ]),
  ));
  await tester.pumpAndSettle();
  expect(hub.relay.readySlots, {'phone', 'desktop'});
  return hub;
}

void main() {
  testWidgets('a tap is replayed on the other instance (separate state)',
      (tester) async {
    await _pumpPair(tester);
    expect(find.text('count: 0'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('inc')).first);
    await tester.pumpAndSettle();
    // Each instance incremented its OWN counter once.
    expect(find.text('count: 1'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('inc')).last);
    await tester.pumpAndSettle();
    expect(find.text('count: 2'), findsNWidgets(2));
  });

  testWidgets('navigation follows because taps are replayed by text',
      (tester) async {
    await _pumpPair(tester);
    await tester.tap(find.text('Row 3').first);
    await tester.pumpAndSettle();
    expect(find.text('Opened 3'), findsNWidgets(2));
  });

  testWidgets('the back button is replayed (matched by its tooltip)',
      (tester) async {
    final hub = await _pumpPair(tester);
    await tester.tap(find.text('Row 2').first);
    await tester.pumpAndSettle();
    expect(find.text('Opened 2'), findsNWidgets(2));
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Opened 2'), findsNothing);
    expect(hub.relay.outOfSync, isEmpty);
  });

  testWidgets('text input is mirrored into the matching field', (tester) async {
    await _pumpPair(tester);
    await tester.enterText(find.byKey(const ValueKey('name')).first, 'Abd');
    await tester.pumpAndSettle();
    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.map((f) => f.controller.text), ['Abd', 'Abd']);
  });

  testWidgets('scrolling is mirrored by fraction', (tester) async {
    await _pumpPair(tester);
    await tester.drag(
        find.byKey(const ValueKey('list')).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final positions = tester
        .stateList<ScrollableState>(find.descendant(
            of: find.byKey(const ValueKey('list')),
            matching: find.byType(Scrollable)))
        .map((s) => ScrollMatcher.fractionOf(s.position))
        .toList();
    expect(positions.first, greaterThan(0));
    expect(positions.last, closeTo(positions.first, 0.02));
  });

  testWidgets('a target that does not exist marks the device out of sync',
      (tester) async {
    final hub = await _pumpPair(tester);
    await tester.tap(find.text('Wide only'));
    await tester.pumpAndSettle();
    expect(hub.relay.outOfSync.keys, ['phone']);
    expect(hub.relay.outOfSync['phone'], contains('Wide only'));

    // The next action that works brings it back in sync.
    await tester.tap(find.byKey(const ValueKey('inc')).last);
    await tester.pumpAndSettle();
    expect(hub.relay.outOfSync, isEmpty);
  });

  testWidgets('input sync can be switched off at the relay', (tester) async {
    var enabled = true;
    final hub = LocalMirrorHub();
    final relay = MirrorRelay(
      sendTo: (slot, message) {},
      isInputSyncEnabled: () => enabled,
    );
    enabled = false;
    relay.receive({'type': 'ready', 'from': 'a'});
    relay.receive({'type': 'ready', 'from': 'b'});
    relay.receive({'type': 'nomatch', 'from': 'a', 'what': 'x'});
    expect(relay.outOfSync.keys, ['a']);
    relay.receive({'type': 'ok', 'from': 'a'});
    expect(relay.outOfSync, isEmpty);
    expect(hub.relay.readySlots, isEmpty);
  });

  test('frame config round-trips through the URL', () {
    final config = MirrorFrameConfig(
      slotId: 'ar+dark/iphone_15',
      device: MirrorDevices.iPhone15,
      variant: MirrorVariant.arabic.combine(MirrorVariant.dark),
    );
    final uri = config.applyTo(Uri.parse('http://localhost:8080/?x=1'));
    expect(uri.queryParameters['x'], '1');
    final back = MirrorFrameConfig.fromUri(uri)!;
    expect(back.slotId, 'ar+dark/iphone_15');
    expect(back.device.size, const Size(393, 852));
    expect(back.device.safeArea, MirrorDevices.iPhone15.safeArea);
    expect(back.variant!.locale, const Locale('ar'));
    expect(back.variant!.themeMode, ThemeMode.dark);
    expect(back.variant!.resolvedTextDirection, TextDirection.rtl);
    expect(MirrorFrameConfig.fromUri(Uri.parse('http://x/')), isNull);
  });

  testWidgets('isolated mode falls back to in-process off the web',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ResponsiveMirror(
      enabled: true,
      mode: MirrorMode.isolated,
      devices: [MirrorDevices.iPhone15, MirrorDevices.laptop],
      child: MaterialApp(home: Text('fallback')),
    ));
    expect(find.text('fallback'), findsNWidgets(2));
  });
}

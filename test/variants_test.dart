import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_mirror/responsive_mirror.dart';

import 'helpers.dart';

void main() {
  testWidgets('renders devices × variants with RTL for Arabic and dark theme',
      (tester) async {
    useLargeWindow(tester);
    final seen = <String, (TextDirection, Brightness, Locale)>{};

    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
      variants: MirrorVariant.matrix(
        [MirrorVariant.english, MirrorVariant.arabic],
        [MirrorVariant.light, MirrorVariant.dark],
      ),
      builder: (context, slot) => MaterialApp(
        locale: ResponsiveMirror.localeOf(context),
        themeMode: ResponsiveMirror.themeModeOf(context),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          seen[slot!.id] = (
            Directionality.of(context),
            Theme.of(context).brightness,
            Localizations.localeOf(context),
          );
          return const Placeholder();
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(seen, hasLength(8)); // 2 devices × 4 variants
    expect(seen['ar+dark/iphone_15']!.$1, TextDirection.rtl);
    expect(seen['ar+dark/iphone_15']!.$2, Brightness.dark);
    expect(seen['ar+dark/iphone_15']!.$3, const Locale('ar'));
    expect(seen['ar+light/laptop_1366']!.$1, TextDirection.rtl);
    expect(seen['ar+light/laptop_1366']!.$2, Brightness.light);
    expect(seen['en+dark/laptop_1366']!.$1, TextDirection.ltr);
    expect(seen['en+dark/laptop_1366']!.$2, Brightness.dark);
    expect(seen['en+light/iphone_15']!.$3, const Locale('en'));
    expect(find.text('العربية · Dark'), findsWidgets);
  });

  testWidgets('dark variant works without wiring themeMode (ThemeMode.system)',
      (tester) async {
    useLargeWindow(tester);
    final brightness = <String, Brightness>{};
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      devices: const [MirrorDevices.iPhone15],
      variants: const [MirrorVariant.light, MirrorVariant.dark],
      builder: (context, slot) => MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          brightness[slot!.id] = Theme.of(context).brightness;
          return const SizedBox();
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(brightness['light/iphone_15'], Brightness.light);
    expect(brightness['dark/iphone_15'], Brightness.dark);
  });

  testWidgets('variants can be hidden from the controller', (tester) async {
    useLargeWindow(tester);
    final controller = ResponsiveMirrorController(
      devices: const [MirrorDevices.iPhone15, MirrorDevices.iPadAir],
      variants: const [MirrorVariant.english, MirrorVariant.arabic],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      controller: controller,
      child: const MaterialApp(home: Text('x')),
    ));
    expect(find.text('x'), findsNWidgets(4));
    controller.toggleVariant(MirrorVariant.arabic);
    await tester.pump();
    expect(find.text('x'), findsNWidgets(2));
    controller.toggleVariant(MirrorVariant.english);
    await tester.pump();
    // No visible variant: devices are rendered once, without overrides.
    expect(find.text('x'), findsNWidgets(2));
  });

  test('variant helpers', () {
    expect(MirrorVariant.arabic.resolvedTextDirection, TextDirection.rtl);
    expect(MirrorVariant.english.resolvedTextDirection, TextDirection.ltr);
    expect(MirrorVariant.dark.resolvedTextDirection, isNull);
    final combo = MirrorVariant.arabic.combine(MirrorVariant.dark);
    expect(combo.id, 'ar+dark');
    expect(combo.locale, const Locale('ar'));
    expect(combo.themeMode, ThemeMode.dark);
    expect(MirrorVariant.locale(const Locale('he')).resolvedTextDirection,
        TextDirection.rtl);
    expect(MirrorVariant.theme(ThemeMode.dark).label, 'Dark');
  });

  testWidgets('navigation sync reaches every device in every variant',
      (tester) async {
    useLargeWindow(tester);
    await tester.pumpWidget(ResponsiveMirror(
      enabled: true,
      devices: const [MirrorDevices.iPhone15, MirrorDevices.laptop],
      variants: const [MirrorVariant.english, MirrorVariant.arabic],
      builder: (context, slot) => MaterialApp(
        navigatorObservers: [ResponsiveMirror.navigatorObserverOf(context)],
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const DetailsPage(title: 'A')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open')).last);
    await tester.pumpAndSettle();
    expect(find.text('Details A'), findsNWidgets(4));
  });
}

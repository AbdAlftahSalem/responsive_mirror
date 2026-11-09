import 'package:flutter/material.dart';

/// A way to render the same screen differently: another locale (and text
/// direction), another theme mode or another text scale.
///
/// The mirror renders every device once per visible variant, as a matrix
/// (devices × variants).
///
/// What the mirror applies on its own:
/// * [themeMode] sets `MediaQuery.platformBrightness`, so apps that use
///   `ThemeMode.system` (the default) with a `darkTheme` switch automatically.
/// * [textScale] multiplies the device text scale.
/// * [textDirection] (or the direction implied by [locale]) wraps the app in a
///   [Directionality].
///
/// What your app reads: [locale] and [themeMode] through
/// `ResponsiveMirror.localeOf(context)` and `ResponsiveMirror.themeModeOf(context)`
/// (pass them to `MaterialApp.locale` / `MaterialApp.themeMode`).
@immutable
class MirrorVariant {
  /// Creates a variant.
  const MirrorVariant({
    required this.id,
    required this.label,
    this.locale,
    this.themeMode,
    this.textDirection,
    this.textScale,
  });

  /// A locale variant. RTL languages get [TextDirection.rtl].
  factory MirrorVariant.locale(Locale locale, {String? label}) => MirrorVariant(
        id: locale.toLanguageTag(),
        label: label ?? locale.toLanguageTag(),
        locale: locale,
      );

  /// A theme variant.
  factory MirrorVariant.theme(ThemeMode mode) => MirrorVariant(
        id: mode.name,
        label: '${mode.name[0].toUpperCase()}${mode.name.substring(1)}',
        themeMode: mode,
      );

  /// English, left to right.
  static const MirrorVariant english =
      MirrorVariant(id: 'en', label: 'English', locale: Locale('en'));

  /// Arabic, right to left.
  static const MirrorVariant arabic =
      MirrorVariant(id: 'ar', label: 'العربية', locale: Locale('ar'));

  /// Light theme.
  static const MirrorVariant light =
      MirrorVariant(id: 'light', label: 'Light', themeMode: ThemeMode.light);

  /// Dark theme.
  static const MirrorVariant dark =
      MirrorVariant(id: 'dark', label: 'Dark', themeMode: ThemeMode.dark);

  /// Large text (accessibility check, 1.5×).
  static const MirrorVariant largeText =
      MirrorVariant(id: 'text150', label: 'Text 150%', textScale: 1.5);

  /// Unique id inside one mirror.
  final String id;

  /// Label shown above the row of devices.
  final String label;

  /// Locale override, or null to keep the app's own locale.
  final Locale? locale;

  /// Theme mode override, or null to keep the app's own.
  final ThemeMode? themeMode;

  /// Explicit text direction. When null it is derived from [locale].
  final TextDirection? textDirection;

  /// Multiplies the device's text scale.
  final double? textScale;

  /// Language codes written right to left.
  static const Set<String> rtlLanguages = {
    'ar',
    'fa',
    'he',
    'iw',
    'ur',
    'ps',
    'sd',
    'ug',
    'yi',
    'ku',
    'dv',
    'ckb'
  };

  /// [textDirection], or the direction of [locale], or null.
  TextDirection? get resolvedTextDirection {
    if (textDirection != null) return textDirection;
    final code = locale?.languageCode;
    if (code == null) return null;
    return rtlLanguages.contains(code) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// The brightness implied by [themeMode], if any.
  Brightness? get brightness => switch (themeMode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        _ => null,
      };

  /// Merges two variants; fields of [other] win when both are set.
  MirrorVariant combine(MirrorVariant other) => MirrorVariant(
        id: '$id+${other.id}',
        label: '$label · ${other.label}',
        locale: other.locale ?? locale,
        themeMode: other.themeMode ?? themeMode,
        textDirection: other.textDirection ?? textDirection,
        textScale: other.textScale ?? textScale,
      );

  /// Every combination of [first] and [second], e.g. locales × themes.
  static List<MirrorVariant> matrix(
    List<MirrorVariant> first,
    List<MirrorVariant> second,
  ) =>
      [
        for (final a in first)
          for (final b in second) a.combine(b),
      ];

  /// Applies the media-level parts of this variant to [data].
  MediaQueryData applyTo(MediaQueryData data) {
    var result = data;
    final b = brightness;
    if (b != null) result = result.copyWith(platformBrightness: b);
    final scale = textScale;
    if (scale != null) {
      result = result.copyWith(
        textScaler: TextScaler.linear(result.textScaler.scale(1) * scale),
      );
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is MirrorVariant &&
      other.id == id &&
      other.label == label &&
      other.locale == locale &&
      other.themeMode == themeMode &&
      other.textDirection == textDirection &&
      other.textScale == textScale;

  @override
  int get hashCode =>
      Object.hash(id, label, locale, themeMode, textDirection, textScale);

  @override
  String toString() => 'MirrorVariant($id)';
}

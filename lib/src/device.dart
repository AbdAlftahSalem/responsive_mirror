import 'package:flutter/widgets.dart';

/// The family a [MirrorDevice] belongs to. Used for the frame drawn around it.
enum MirrorDeviceType {
  /// A phone-sized screen.
  phone,

  /// A tablet-sized screen.
  tablet,

  /// A laptop screen (drawn with a keyboard base).
  laptop,

  /// A desktop monitor (drawn with a stand).
  desktop,

  /// Anything else.
  custom,
}

/// A screen that `ResponsiveMirror` renders your app in.
///
/// Each device gets its own [MediaQueryData]: [size], [devicePixelRatio],
/// [safeArea] (padding + viewPadding) and [textScale]. The [platform] is
/// exposed through `MirrorSlot.platform` so your app can pass it to
/// `ThemeData.platform` if you want per-device platform look.
@immutable
class MirrorDevice {
  /// Creates a device description.
  const MirrorDevice({
    required this.id,
    required this.name,
    required this.size,
    this.devicePixelRatio = 1.0,
    this.safeArea = EdgeInsets.zero,
    this.platform = TargetPlatform.android,
    this.type = MirrorDeviceType.custom,
    this.textScale = 1.0,
    this.cornerRadius = 0,
  });

  /// Creates a custom device. The [id] defaults to a slug of [name].
  factory MirrorDevice.custom({
    required String name,
    required Size size,
    String? id,
    double devicePixelRatio = 1.0,
    EdgeInsets safeArea = EdgeInsets.zero,
    TargetPlatform platform = TargetPlatform.android,
    MirrorDeviceType type = MirrorDeviceType.custom,
    double textScale = 1.0,
    double cornerRadius = 0,
  }) {
    return MirrorDevice(
      id: id ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      name: name,
      size: size,
      devicePixelRatio: devicePixelRatio,
      safeArea: safeArea,
      platform: platform,
      type: type,
      textScale: textScale,
      cornerRadius: cornerRadius,
    );
  }

  /// Stable identifier, unique inside one mirror.
  final String id;

  /// Human readable name shown above the frame.
  final String name;

  /// Logical size of the screen (what `MediaQuery.sizeOf` returns).
  final Size size;

  /// Device pixel ratio reported to the app.
  final double devicePixelRatio;

  /// Safe area insets (notch, home indicator, status bar).
  final EdgeInsets safeArea;

  /// Target platform suggested for this device.
  final TargetPlatform platform;

  /// Which family this device belongs to.
  final MirrorDeviceType type;

  /// Text scale factor reported through `MediaQuery.textScalerOf`.
  final double textScale;

  /// Corner radius of the screen, in logical pixels.
  final double cornerRadius;

  /// Short label such as `393×852 @3x`.
  String get specLabel {
    final dpr = devicePixelRatio == devicePixelRatio.roundToDouble()
        ? devicePixelRatio.toStringAsFixed(0)
        : devicePixelRatio.toStringAsFixed(2);
    return '${size.width.round()}×${size.height.round()} @${dpr}x';
  }

  /// Returns [base] with this device's metrics applied.
  MediaQueryData applyTo(MediaQueryData base) {
    return base.copyWith(
      size: size,
      devicePixelRatio: devicePixelRatio,
      padding: safeArea,
      viewPadding: safeArea,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
      textScaler: TextScaler.linear(textScale),
      displayFeatures: const [],
    );
  }

  /// Returns a copy with the given fields replaced.
  MirrorDevice copyWith({
    String? id,
    String? name,
    Size? size,
    double? devicePixelRatio,
    EdgeInsets? safeArea,
    TargetPlatform? platform,
    MirrorDeviceType? type,
    double? textScale,
    double? cornerRadius,
  }) {
    return MirrorDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      safeArea: safeArea ?? this.safeArea,
      platform: platform ?? this.platform,
      type: type ?? this.type,
      textScale: textScale ?? this.textScale,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MirrorDevice &&
        other.id == id &&
        other.name == name &&
        other.size == size &&
        other.devicePixelRatio == devicePixelRatio &&
        other.safeArea == safeArea &&
        other.platform == platform &&
        other.type == type &&
        other.textScale == textScale &&
        other.cornerRadius == cornerRadius;
  }

  @override
  int get hashCode => Object.hash(id, name, size, devicePixelRatio, safeArea,
      platform, type, textScale, cornerRadius);

  @override
  String toString() => 'MirrorDevice($id, $specLabel)';
}

/// Ready-made devices.
abstract final class MirrorDevices {
  /// iPhone 15 (393×852 @3x).
  static const MirrorDevice iPhone15 = MirrorDevice(
    id: 'iphone_15',
    name: 'iPhone 15',
    size: Size(393, 852),
    devicePixelRatio: 3,
    safeArea: EdgeInsets.only(top: 59, bottom: 34),
    platform: TargetPlatform.iOS,
    type: MirrorDeviceType.phone,
    cornerRadius: 48,
  );

  /// iPhone SE (375×667 @2x), a small phone.
  static const MirrorDevice iPhoneSE = MirrorDevice(
    id: 'iphone_se',
    name: 'iPhone SE',
    size: Size(375, 667),
    devicePixelRatio: 2,
    safeArea: EdgeInsets.only(top: 20),
    platform: TargetPlatform.iOS,
    type: MirrorDeviceType.phone,
    cornerRadius: 8,
  );

  /// Pixel 8 (412×915 @2.625x).
  static const MirrorDevice pixel8 = MirrorDevice(
    id: 'pixel_8',
    name: 'Pixel 8',
    size: Size(412, 915),
    devicePixelRatio: 2.625,
    safeArea: EdgeInsets.only(top: 24, bottom: 24),
    platform: TargetPlatform.android,
    type: MirrorDeviceType.phone,
    cornerRadius: 36,
  );

  /// iPad Air (820×1180 @2x).
  static const MirrorDevice iPadAir = MirrorDevice(
    id: 'ipad_air',
    name: 'iPad Air',
    size: Size(820, 1180),
    devicePixelRatio: 2,
    safeArea: EdgeInsets.only(top: 24, bottom: 20),
    platform: TargetPlatform.iOS,
    type: MirrorDeviceType.tablet,
    cornerRadius: 18,
  );

  /// A common laptop screen (1366×768).
  static const MirrorDevice laptop = MirrorDevice(
    id: 'laptop_1366',
    name: 'Laptop',
    size: Size(1366, 768),
    platform: TargetPlatform.windows,
    type: MirrorDeviceType.laptop,
  );

  /// A 1440×900 laptop (MacBook Air class).
  static const MirrorDevice laptop1440 = MirrorDevice(
    id: 'laptop_1440',
    name: 'Laptop 1440',
    size: Size(1440, 900),
    devicePixelRatio: 2,
    platform: TargetPlatform.macOS,
    type: MirrorDeviceType.laptop,
  );

  /// A full HD desktop monitor (1920×1080).
  static const MirrorDevice desktop = MirrorDevice(
    id: 'desktop_1920',
    name: 'Desktop',
    size: Size(1920, 1080),
    platform: TargetPlatform.linux,
    type: MirrorDeviceType.desktop,
  );

  /// The default set: phone, tablet, laptop and desktop.
  static const List<MirrorDevice> defaults = [
    iPhone15,
    iPadAir,
    laptop,
    desktop,
  ];

  /// Every preset in this class.
  static const List<MirrorDevice> all = [
    iPhoneSE,
    iPhone15,
    pixel8,
    iPadAir,
    laptop,
    laptop1440,
    desktop,
  ];
}

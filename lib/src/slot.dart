import 'package:flutter/material.dart';

import 'device.dart';
import 'variant.dart';

/// Everything one rendered copy of your app needs to know about where it is
/// running: the device, and the navigator observer that keeps it in sync.
///
/// Read it with `ResponsiveMirror.slotOf(context)` or receive it in
/// `ResponsiveMirror.builder`.
@immutable
class MirrorSlot {
  /// Creates a slot. Normally only `ResponsiveMirror` creates these.
  const MirrorSlot({
    required this.id,
    required this.device,
    required this.navigatorObserver,
    this.variant,
  });

  /// Builds the slot id for [device] in [variant].
  static String idFor(MirrorDevice device, [MirrorVariant? variant]) =>
      variant == null ? device.id : '${variant.id}/${device.id}';

  /// Unique id of this copy inside the mirror.
  final String id;

  /// The device this copy is rendered in.
  final MirrorDevice device;

  /// Add this to `MaterialApp.navigatorObservers` so navigation is mirrored.
  final NavigatorObserver navigatorObserver;

  /// The variant (locale / theme / text scale) of this copy, if any.
  final MirrorVariant? variant;

  /// Locale this copy should use, or null to keep the app's own.
  Locale? get locale => variant?.locale;

  /// Theme mode this copy should use, or null to keep the app's own.
  ThemeMode? get themeMode => variant?.themeMode;

  /// Text direction implied by the variant, if any.
  TextDirection? get textDirection => variant?.resolvedTextDirection;

  /// The platform suggested by [device]; pass it to `ThemeData.platform` for a
  /// per-device platform look.
  TargetPlatform get platform => device.platform;

  @override
  bool operator ==(Object other) =>
      other is MirrorSlot &&
      other.id == id &&
      other.device == device &&
      other.variant == variant &&
      other.navigatorObserver == navigatorObserver;

  @override
  int get hashCode => Object.hash(id, device, variant, navigatorObserver);
}

/// Makes a [MirrorSlot] available to the app subtree rendered inside it.
class MirrorSlotScope extends InheritedWidget {
  /// Creates the scope.
  const MirrorSlotScope({super.key, required this.slot, required super.child});

  /// The slot for this subtree.
  final MirrorSlot slot;

  /// The nearest slot, or null outside a mirror.
  static MirrorSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MirrorSlotScope>()?.slot;

  @override
  bool updateShouldNotify(MirrorSlotScope oldWidget) => slot != oldWidget.slot;
}

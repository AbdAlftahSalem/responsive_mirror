import 'package:flutter/foundation.dart';

import 'device.dart';
import 'variant.dart';

/// Holds the state of a `ResponsiveMirror`: which devices are shown, the zoom
/// level and which kinds of synchronisation are on.
///
/// Pass your own instance to `ResponsiveMirror.controller` to drive the mirror
/// from code (for example from a test or a custom toolbar).
class ResponsiveMirrorController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [visibleDeviceIds] defaults to every device in [devices].
  /// A null [zoom] means "fit to the available width".
  ResponsiveMirrorController({
    List<MirrorDevice> devices = MirrorDevices.defaults,
    Iterable<String>? visibleDeviceIds,
    double? zoom,
    bool syncNavigation = true,
    bool syncScroll = true,
    bool mirrorVisible = true,
    List<MirrorVariant> variants = const [],
    Iterable<String>? visibleVariantIds,
  })  : _devices = List.unmodifiable(devices),
        _variants = List.unmodifiable(variants),
        _visibleVariants = {
          ...(visibleVariantIds ?? variants.map((v) => v.id))
        },
        _visible = {...(visibleDeviceIds ?? devices.map((d) => d.id))},
        _zoom = zoom == null ? null : _clampZoom(zoom),
        _syncNavigation = syncNavigation,
        _syncScroll = syncScroll,
        _mirrorVisible = mirrorVisible {
    assert(
      devices.map((d) => d.id).toSet().length == devices.length,
      'Every MirrorDevice needs a unique id.',
    );
    assert(
      variants.map((v) => v.id).toSet().length == variants.length,
      'Every MirrorVariant needs a unique id.',
    );
  }

  /// Smallest zoom the toolbar allows.
  static const double minZoom = 0.1;

  /// Largest zoom the toolbar allows.
  static const double maxZoom = 2.0;

  static double _clampZoom(double z) => z.clamp(minZoom, maxZoom).toDouble();

  List<MirrorDevice> _devices;
  final Set<String> _visible;
  List<MirrorVariant> _variants;
  final Set<String> _visibleVariants;
  double? _zoom;
  bool _syncNavigation;
  bool _syncScroll;
  bool _mirrorVisible;

  /// Every device the mirror knows about (visible or not).
  List<MirrorDevice> get devices => _devices;
  set devices(List<MirrorDevice> value) {
    _devices = List.unmodifiable(value);
    _visible.removeWhere((id) => !value.any((d) => d.id == id));
    notifyListeners();
  }

  /// Devices currently rendered, in [devices] order.
  List<MirrorDevice> get visibleDevices =>
      _devices.where((d) => _visible.contains(d.id)).toList(growable: false);

  /// Whether [device] is currently rendered.
  bool isVisible(MirrorDevice device) => _visible.contains(device.id);

  /// Shows or hides [device].
  void setVisible(MirrorDevice device, bool visible) {
    final changed =
        visible ? _visible.add(device.id) : _visible.remove(device.id);
    if (changed) notifyListeners();
  }

  /// Flips the visibility of [device].
  void toggleDevice(MirrorDevice device) =>
      setVisible(device, !isVisible(device));

  /// Every variant the mirror knows about. Empty means "no variants": each
  /// device is rendered once, with the app's own locale and theme.
  List<MirrorVariant> get variants => _variants;
  set variants(List<MirrorVariant> value) {
    _variants = List.unmodifiable(value);
    _visibleVariants.removeWhere((id) => !value.any((v) => v.id == id));
    notifyListeners();
  }

  /// Variants currently rendered, in [variants] order.
  List<MirrorVariant> get visibleVariants => _variants
      .where((v) => _visibleVariants.contains(v.id))
      .toList(growable: false);

  /// Whether [variant] is currently rendered.
  bool isVariantVisible(MirrorVariant variant) =>
      _visibleVariants.contains(variant.id);

  /// Shows or hides [variant].
  void setVariantVisible(MirrorVariant variant, bool visible) {
    final changed = visible
        ? _visibleVariants.add(variant.id)
        : _visibleVariants.remove(variant.id);
    if (changed) notifyListeners();
  }

  /// Flips the visibility of [variant].
  void toggleVariant(MirrorVariant variant) =>
      setVariantVisible(variant, !isVariantVisible(variant));

  /// Zoom factor applied to every device (1.0 = one logical pixel per logical
  /// pixel). Null means "fit to width".
  double? get zoom => _zoom;
  set zoom(double? value) {
    final next = value == null ? null : _clampZoom(value);
    if (next == _zoom) return;
    _zoom = next;
    notifyListeners();
  }

  /// Multiplies the current zoom by 1.25, starting from [current] when the
  /// mirror is in "fit" mode.
  void zoomIn([double current = 0.4]) => zoom = (_zoom ?? current) * 1.25;

  /// Divides the current zoom by 1.25.
  void zoomOut([double current = 0.4]) => zoom = (_zoom ?? current) / 1.25;

  /// Returns to "fit to width".
  void fit() => zoom = null;

  /// Whether push/pop/replace on one device is replayed on the others.
  bool get syncNavigation => _syncNavigation;
  set syncNavigation(bool value) {
    if (value == _syncNavigation) return;
    _syncNavigation = value;
    notifyListeners();
  }

  /// Whether scrolling one device scrolls the matching list on the others.
  bool get syncScroll => _syncScroll;
  set syncScroll(bool value) {
    if (value == _syncScroll) return;
    _syncScroll = value;
    notifyListeners();
  }

  /// When false the mirror steps aside and shows your app once, full size.
  bool get mirrorVisible => _mirrorVisible;
  set mirrorVisible(bool value) {
    if (value == _mirrorVisible) return;
    _mirrorVisible = value;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import 'device.dart';

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
  })  : _devices = List.unmodifiable(devices),
        _visible = {...(visibleDeviceIds ?? devices.map((d) => d.id))},
        _zoom = zoom == null ? null : _clampZoom(zoom),
        _syncNavigation = syncNavigation,
        _syncScroll = syncScroll,
        _mirrorVisible = mirrorVisible {
    assert(
      devices.map((d) => d.id).toSet().length == devices.length,
      'Every MirrorDevice needs a unique id.',
    );
  }

  /// Smallest zoom the toolbar allows.
  static const double minZoom = 0.1;

  /// Largest zoom the toolbar allows.
  static const double maxZoom = 2.0;

  static double _clampZoom(double z) => z.clamp(minZoom, maxZoom).toDouble();

  List<MirrorDevice> _devices;
  final Set<String> _visible;
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

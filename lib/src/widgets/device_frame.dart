import 'package:flutter/material.dart';

import '../device.dart';

/// Draws a simple, flat frame around a device screen: rounded bezel for
/// phones and tablets, a keyboard base for laptops and a stand for desktops.
class MirrorDeviceFrame extends StatelessWidget {
  /// Creates a frame around [screen], which is already scaled by [scale].
  const MirrorDeviceFrame({
    super.key,
    required this.device,
    required this.scale,
    required this.screen,
    this.highlight,
  });

  /// The device being framed.
  final MirrorDevice device;

  /// The zoom factor the screen is drawn at.
  final double scale;

  /// The (already scaled) screen widget.
  final Widget screen;

  /// Optional outline colour (used for the overflow badge in v0.3).
  final Color? highlight;

  static const Color _bezel = Color(0xFF1E1E24);

  static double _bezelFor(MirrorDevice device, double scale) {
    final handheld = device.type == MirrorDeviceType.phone ||
        device.type == MirrorDeviceType.tablet;
    return (handheld ? 12.0 : 10.0) * scale.clamp(0.35, 1.0);
  }

  /// The size the framed device takes at [scale], bezel, keyboard base and
  /// stand included.
  static Size outerSize(MirrorDevice device, double scale) {
    final bezel = _bezelFor(device, scale);
    final w = device.size.width * scale + bezel * 2 + 2;
    final h = device.size.height * scale + bezel * 2 + 2;
    switch (device.type) {
      case MirrorDeviceType.laptop:
        return Size(w * 1.12, h + (14 * scale).clamp(5.0, 14.0));
      case MirrorDeviceType.desktop:
        return Size(w,
            h + (60 * scale).clamp(10.0, 60.0) + (10 * scale).clamp(4.0, 10.0));
      case MirrorDeviceType.phone:
      case MirrorDeviceType.tablet:
      case MirrorDeviceType.custom:
        return Size(w, h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = device.type;
    final isHandheld =
        type == MirrorDeviceType.phone || type == MirrorDeviceType.tablet;
    final bezel = _bezelFor(device, scale);
    final screenRadius = device.cornerRadius * scale;
    final body = Container(
      padding: EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: _bezel,
        borderRadius: BorderRadius.circular(
            isHandheld ? screenRadius + bezel : 6 + bezel * 0.5),
        border: highlight == null
            ? Border.all(color: const Color(0xFF3A3A44), width: 1)
            : Border.all(color: highlight!, width: 3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isHandheld ? screenRadius : 2),
        child: screen,
      ),
    );
    final width = device.size.width * scale + bezel * 2;
    switch (type) {
      case MirrorDeviceType.laptop:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          body,
          Container(
            width: width * 1.12,
            height: (14 * scale).clamp(5.0, 14.0),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A32),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ]);
      case MirrorDeviceType.desktop:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          body,
          Container(
            width: width * 0.12,
            height: (60 * scale).clamp(10.0, 60.0),
            color: const Color(0xFF2A2A32),
          ),
          Container(
            width: width * 0.3,
            height: (10 * scale).clamp(4.0, 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A32),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ]);
      case MirrorDeviceType.phone:
      case MirrorDeviceType.tablet:
      case MirrorDeviceType.custom:
        return body;
    }
  }
}

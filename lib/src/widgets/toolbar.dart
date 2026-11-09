import 'package:flutter/material.dart';

import '../controller.dart';

/// The bar above the device grid: device toggles, sync switches and zoom.
class MirrorToolbar extends StatelessWidget {
  /// Creates the toolbar for [controller].
  const MirrorToolbar({
    super.key,
    required this.controller,
    required this.fitScale,
    this.extraActions = const [],
  });

  /// The controller the toolbar edits.
  final ResponsiveMirrorController controller;

  /// Returns the zoom that "fit" currently resolves to.
  final double Function() fitScale;

  /// Extra widgets appended at the end (used by later features).
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final zoom = controller.zoom ?? fitScale();
    return Material(
      color: const Color(0xFF161922),
      elevation: 2,
      child: SizedBox(
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.devices_other, color: Color(0xFF8C97FF)),
              const SizedBox(width: 8),
              const Text(
                'responsive_mirror',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(width: 16),
              for (final device in controller.devices)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    key: ValueKey('rm_device_chip_${device.id}'),
                    label: Text(device.name),
                    selected: controller.isVisible(device),
                    onSelected: (_) => controller.toggleDevice(device),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const _Divider(),
              _Toggle(
                key: const ValueKey('rm_sync_nav'),
                icon: Icons.alt_route,
                tooltip: 'Sync navigation',
                value: controller.syncNavigation,
                onChanged: (v) => controller.syncNavigation = v,
              ),
              _Toggle(
                key: const ValueKey('rm_sync_scroll'),
                icon: Icons.swap_vert,
                tooltip: 'Sync scrolling',
                value: controller.syncScroll,
                onChanged: (v) => controller.syncScroll = v,
              ),
              const _Divider(),
              IconButton(
                key: const ValueKey('rm_zoom_out'),
                tooltip: 'Zoom out (Ctrl + wheel)',
                icon: const Icon(Icons.zoom_out),
                onPressed: () => controller.zoomOut(fitScale()),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(zoom * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              IconButton(
                key: const ValueKey('rm_zoom_in'),
                tooltip: 'Zoom in (Ctrl + wheel)',
                icon: const Icon(Icons.zoom_in),
                onPressed: () => controller.zoomIn(fitScale()),
              ),
              TextButton(
                key: const ValueKey('rm_zoom_fit'),
                onPressed: controller.zoom == null ? null : controller.fit,
                child: const Text('Fit'),
              ),
              ...extraActions,
              const _Divider(),
              IconButton(
                key: const ValueKey('rm_exit'),
                tooltip: 'Show the app once, full size',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => controller.mirrorVisible = false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white12,
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: '$tooltip: ${value ? 'on' : 'off'}',
      isSelected: value,
      style: IconButton.styleFrom(
        backgroundColor: value ? scheme.primaryContainer : null,
      ),
      icon: Icon(icon),
      onPressed: () => onChanged(!value),
    );
  }
}

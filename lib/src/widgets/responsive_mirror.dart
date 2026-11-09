import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller.dart';
import '../device.dart';
import '../slot.dart';
import '../sync/navigation_sync.dart';
import '../sync/scroll_sync.dart';
import 'device_frame.dart';
import 'toolbar.dart';

/// Builds one copy of your app for [slot].
///
/// [slot] is null when the mirror is disabled (for example in release mode)
/// and your app is shown once, as is.
typedef MirrorAppBuilder = Widget Function(
    BuildContext context, MirrorSlot? slot);

/// Shows your app on several devices at the same time, side by side.
///
/// ```dart
/// void main() => runApp(ResponsiveMirror(child: MyApp()));
/// ```
///
/// Every device gets its own [MediaQuery] (size, pixel ratio, safe area,
/// text scale) and its own copy of your widget tree, so it has its own
/// [Navigator]. App state that lives above your `MaterialApp` (providers,
/// singletons, blocs created outside the widget) is shared: a tap on one
/// device changes the shared state and every device rebuilds. Navigation and
/// scrolling are mirrored by the mirror itself; for navigation add
/// `ResponsiveMirror.navigatorObserverOf(context)` to your
/// `MaterialApp.navigatorObservers`.
///
/// By default the mirror is only active in debug builds ([enabled] defaults
/// to [kDebugMode]); in release builds it returns your app untouched.
class ResponsiveMirror extends StatefulWidget {
  /// Mirrors [child] (usually your `MyApp`) or the widget returned by
  /// [builder] on every device.
  const ResponsiveMirror({
    super.key,
    this.child,
    this.builder,
    this.devices = MirrorDevices.defaults,
    this.controller,
    this.enabled = kDebugMode,
    this.syncNavigation = true,
    this.syncScroll = true,
    this.zoom,
    this.showToolbar = true,
    this.backgroundColor = const Color(0xFF0E1016),
  }) : assert(child != null || builder != null,
            'Provide either a child or a builder.');

  /// The app to mirror. Ignored when [builder] is set.
  final Widget? child;

  /// Builds the app per device. Use it when you need the [MirrorSlot]
  /// (for example to pass `slot.platform` to your theme).
  final MirrorAppBuilder? builder;

  /// Devices to show when no [controller] is given.
  final List<MirrorDevice> devices;

  /// Optional external controller.
  final ResponsiveMirrorController? controller;

  /// When false the mirror is skipped and the app is returned as is.
  /// Defaults to [kDebugMode].
  final bool enabled;

  /// Initial navigation sync state when no [controller] is given.
  final bool syncNavigation;

  /// Initial scroll sync state when no [controller] is given.
  final bool syncScroll;

  /// Initial zoom when no [controller] is given; null fits to width.
  final double? zoom;

  /// Whether the toolbar is shown above the grid.
  final bool showToolbar;

  /// Background of the canvas behind the devices.
  final Color backgroundColor;

  /// The [MirrorSlot] of the device [context] is rendered in, or null when
  /// [context] is not inside a mirror.
  static MirrorSlot? slotOf(BuildContext context) =>
      MirrorSlotScope.maybeOf(context);

  /// Whether [context] is rendered inside a mirror device.
  static bool isMirrored(BuildContext context) => slotOf(context) != null;

  static final Expando<NavigatorObserver> _passthroughObservers =
      Expando<NavigatorObserver>('responsive_mirror passthrough observer');

  /// The navigator observer to add to `MaterialApp.navigatorObservers`.
  ///
  /// Inside a mirror it is the device's sync observer; outside it is an inert
  /// observer, so the line can stay in your code in release builds.
  static NavigatorObserver navigatorObserverOf(BuildContext context) {
    final slot = slotOf(context);
    if (slot != null) return slot.navigatorObserver;
    return _passthroughObservers[context] ??= NavigatorObserver();
  }

  @override
  State<ResponsiveMirror> createState() => _ResponsiveMirrorState();
}

class _ResponsiveMirrorState extends State<ResponsiveMirror> {
  ResponsiveMirrorController? _ownController;
  late final MirrorNavigationSync _nav;
  late final MirrorScrollSync _scroll;
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  double _lastFitScale = 0.4;

  ResponsiveMirrorController get _controller =>
      widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownController = _createController();
    _nav = MirrorNavigationSync(isEnabled: () => _controller.syncNavigation);
    _scroll = MirrorScrollSync(isEnabled: () => _controller.syncScroll);
  }

  ResponsiveMirrorController _createController() => ResponsiveMirrorController(
        devices: widget.devices,
        zoom: widget.zoom,
        syncNavigation: widget.syncNavigation,
        syncScroll: widget.syncScroll,
      );

  @override
  void didUpdateWidget(ResponsiveMirror oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && _ownController == null) {
      _ownController = _createController();
    } else if (widget.controller != null && _ownController != null) {
      _ownController!.dispose();
      _ownController = null;
    }
    if (_ownController != null &&
        !listEquals(widget.devices, oldWidget.devices)) {
      _ownController!.devices = widget.devices;
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  Widget _buildApp(BuildContext context, MirrorSlot? slot) {
    final builder = widget.builder;
    if (builder != null) return builder(context, slot);
    return widget.child!;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return _buildApp(context, null);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (!_controller.mirrorVisible) return _buildSingle(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'responsive_mirror',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF6C7BFF),
          ),
          home: Scaffold(
            backgroundColor: widget.backgroundColor,
            body: Column(
              children: [
                if (widget.showToolbar)
                  MirrorToolbar(
                    controller: _controller,
                    fitScale: () => _lastFitScale,
                  ),
                Expanded(child: _buildCanvas()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingle(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: _buildApp(context, null)),
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: () => _controller.mirrorVisible = true,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1E1E24),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.devices, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _spacing = 32;
  static const double _padding = 24;
  static const double _labelHeight = 28;

  double _fitScale(List<MirrorDevice> devices, Size available) {
    if (devices.isEmpty) return 0.4;
    final widths = devices.fold<double>(0, (s, d) => s + d.size.width);
    final fixed =
        _padding * 2 + _spacing * (devices.length - 1) + devices.length * 28;
    final byWidth = (available.width - fixed) / widths;
    final tallest = devices.map((d) => d.size.height).reduce(math.max);
    final byHeight =
        (available.height - _padding * 2 - _labelHeight - 80) / tallest;
    return math.max(0.08, math.min(1.0, math.min(byWidth, byHeight)));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed && !keys.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      if (dy < 0) {
        _controller.zoomIn(_lastFitScale);
      } else if (dy > 0) {
        _controller.zoomOut(_lastFitScale);
      }
    });
  }

  Widget _buildCanvas() {
    return LayoutBuilder(builder: (context, constraints) {
      final devices = _controller.visibleDevices;
      if (devices.isEmpty) {
        return const Center(
          child: Text('No device selected',
              style: TextStyle(color: Colors.white54)),
        );
      }
      _lastFitScale = _fitScale(devices, constraints.biggest);
      final scale = _controller.zoom ?? _lastFitScale;
      final widest =
          devices.map((d) => d.size.width * scale + 40).reduce(math.max);
      final contentWidth =
          math.max(constraints.maxWidth - _padding * 2, widest);
      final tiles = [
        for (final device in devices)
          _DeviceTile(
            key: ValueKey(device.id),
            device: device,
            scale: scale,
            slot: MirrorSlot(
              id: device.id,
              device: device,
              navigatorObserver: _nav.observerFor(device.id),
            ),
            nav: _nav,
            scroll: _scroll,
            appBuilder: _buildApp,
          ),
      ];
      return Listener(
        onPointerSignal: _onPointerSignal,
        child: Scrollbar(
          controller: _vertical,
          child: SingleChildScrollView(
            controller: _vertical,
            padding: const EdgeInsets.all(_padding),
            child: Scrollbar(
              controller: _horizontal,
              notificationPredicate: (n) => n.depth == 0,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: Wrap(
                    spacing: _spacing,
                    runSpacing: _spacing,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: tiles,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    super.key,
    required this.device,
    required this.scale,
    required this.slot,
    required this.nav,
    required this.scroll,
    required this.appBuilder,
  });

  final MirrorDevice device;
  final double scale;
  final MirrorSlot slot;
  final MirrorNavigationSync nav;
  final MirrorScrollSync scroll;
  final MirrorAppBuilder appBuilder;

  @override
  Widget build(BuildContext context) {
    final screen = SizedBox(
      width: device.size.width * scale,
      height: device.size.height * scale,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: device.size.width,
          height: device.size.height,
          child: MirrorDeviceHost(
            slot: slot,
            nav: nav,
            scroll: scroll,
            appBuilder: appBuilder,
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: device.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: '   ${device.specLabel}',
                style: const TextStyle(color: Colors.white54),
              ),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        MirrorDeviceFrame(device: device, scale: scale, screen: screen),
      ],
    );
  }
}

/// Hosts one copy of the app at the device's logical size.
@visibleForTesting
class MirrorDeviceHost extends StatefulWidget {
  /// Creates a host.
  const MirrorDeviceHost({
    super.key,
    required this.slot,
    required this.nav,
    required this.scroll,
    required this.appBuilder,
  });

  /// The slot rendered here.
  final MirrorSlot slot;

  /// Navigation hub.
  final MirrorNavigationSync nav;

  /// Scroll hub.
  final MirrorScrollSync scroll;

  /// Builds the app.
  final MirrorAppBuilder appBuilder;

  @override
  State<MirrorDeviceHost> createState() => _MirrorDeviceHostState();
}

class _MirrorDeviceHostState extends State<MirrorDeviceHost> {
  @override
  void initState() {
    super.initState();
    widget.scroll.register(widget.slot.id, context);
  }

  @override
  void didUpdateWidget(MirrorDeviceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.id != widget.slot.id) {
      oldWidget.scroll.unregister(oldWidget.slot.id, context);
      widget.scroll.register(widget.slot.id, context);
    }
  }

  @override
  void dispose() {
    widget.scroll.unregister(widget.slot.id, context);
    widget.nav.unregister(widget.slot.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return MediaQuery(
      data: slot.device.applyTo(MediaQuery.of(context)),
      child: MirrorSlotScope(
        slot: slot,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => widget.scroll.handle(slot.id, n),
          child: RepaintBoundary(
            child:
                Builder(builder: (context) => widget.appBuilder(context, slot)),
          ),
        ),
      ),
    );
  }
}

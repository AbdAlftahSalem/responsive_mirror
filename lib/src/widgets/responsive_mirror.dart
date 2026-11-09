import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../controller.dart';
import '../device.dart';
import '../export/save.dart';
import '../isolated/agent.dart';
import '../isolated/protocol.dart';
import '../isolated/transport.dart';
import '../issues.dart';
import '../slot.dart';
import '../variant.dart';
import '../sync/navigation_sync.dart';
import '../sync/scroll_sync.dart';
import 'device_frame.dart';
import 'issues_panel.dart';
import 'toolbar.dart';

/// How the copies of your app are run.
enum MirrorMode {
  /// Every device renders its own widget tree inside ONE app (default).
  /// App state above `MaterialApp` is shared, so taps are not replayed: the
  /// shared state updates every device. Navigation and scrolling are synced.
  /// Works on every platform.
  inProcess,

  /// Every device is a separate instance of the app with its own state
  /// (web only: one iframe per device running your web build). Taps, text
  /// input and scrolling are replayed on the other instances, matched by
  /// key / semantics label / text. On other platforms the mirror falls back
  /// to [inProcess].
  isolated,
}

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
    this.variants = const [],
    this.controller,
    this.enabled = kDebugMode,
    this.syncNavigation = true,
    this.syncScroll = true,
    this.zoom,
    this.showToolbar = true,
    this.backgroundColor = const Color(0xFF0E1016),
    this.onExport,
    this.mode = MirrorMode.inProcess,
    this.isolatedUrl,
  }) : assert(child != null || builder != null,
            'Provide either a child or a builder.');

  /// The app to mirror. Ignored when [builder] is set.
  final Widget? child;

  /// Builds the app per device. Use it when you need the [MirrorSlot]
  /// (for example to pass `slot.platform` to your theme).
  final MirrorAppBuilder? builder;

  /// Devices to show when no [controller] is given.
  final List<MirrorDevice> devices;

  /// Variants to render every device in (locale / theme / text scale) when
  /// no [controller] is given. Empty renders each device once.
  ///
  /// ```dart
  /// variants: MirrorVariant.matrix(
  ///   [MirrorVariant.english, MirrorVariant.arabic],
  ///   [MirrorVariant.light, MirrorVariant.dark],
  /// ),
  /// ```
  final List<MirrorVariant> variants;

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

  /// Called with the PNGs produced by the toolbar's export button. When null
  /// the files are saved for you: a download on the web,
  /// `responsive_mirror_exports/` in the working directory on desktop, the
  /// temp directory on mobile.
  final Future<void> Function(List<MirrorExport> exports)? onExport;

  /// In-process (default, every platform) or isolated (web only).
  final MirrorMode mode;

  /// Isolated mode: the URL each frame loads. Defaults to the current page
  /// (`Uri.base`), i.e. the same web build; the frame detects it is a frame
  /// from its `rm_*` query parameters and runs as an agent.
  final Uri? isolatedUrl;

  /// The [MirrorSlot] of the device [context] is rendered in, or null when
  /// [context] is not inside a mirror.
  static MirrorSlot? slotOf(BuildContext context) =>
      MirrorSlotScope.maybeOf(context);

  /// Whether [context] is rendered inside a mirror device.
  static bool isMirrored(BuildContext context) => slotOf(context) != null;

  /// The locale the current variant asks for, or null (keep your own).
  ///
  /// `MaterialApp(locale: ResponsiveMirror.localeOf(context) ?? myLocale)`
  static Locale? localeOf(BuildContext context) => slotOf(context)?.locale;

  /// The theme mode the current variant asks for, or null (keep your own).
  ///
  /// `MaterialApp(themeMode: ResponsiveMirror.themeModeOf(context) ?? ThemeMode.system)`
  static ThemeMode? themeModeOf(BuildContext context) =>
      slotOf(context)?.themeMode;

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
  final GlobalKey _gridKey = GlobalKey(debugLabel: 'responsive_mirror grid');
  final Map<String, GlobalKey> _boundaryKeys = {};
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey();
  FlutterExceptionHandler? _previousOnError;
  FlutterExceptionHandler? _installedOnError;
  MirrorFrameConfig? _frame;
  MirrorChannel? _frameChannel;
  final NavigatorObserver _frameObserver = NavigatorObserver();
  MirrorHostTransport? _transport;
  MirrorRelay? _relay;

  bool get _isolatedHost => _relay != null;

  void _setUpIsolated() {
    if (widget.mode != MirrorMode.isolated || _relay != null) return;
    if (!MirrorHostTransport.isSupported) {
      debugPrint('responsive_mirror: isolated mode needs Flutter web '
          '(one iframe per device). Falling back to in-process mode.');
      return;
    }
    late final MirrorHostTransport transport;
    final relay = MirrorRelay(
      sendTo: (slot, message) => transport.send(slot, message),
      isInputSyncEnabled: () => _controller.syncNavigation,
      isScrollSyncEnabled: () => _controller.syncScroll,
      onIssue: _onFrameIssue,
    );
    transport = MirrorHostTransport(onMessage: relay.receive);
    _transport = transport;
    _relay = relay;
  }

  void _onFrameIssue(String slotId, String message) {
    final device = _deviceOf(slotId);
    if (device == null) return;
    MirrorVariant? variant;
    for (final v in _controller.variants) {
      if (slotId == MirrorSlot.idFor(device, v)) variant = v;
    }
    _controller.reportIssue(MirrorIssue(
      slotId: slotId,
      deviceName: device.name,
      variantLabel: variant?.label,
      kind: message.contains('overflowed')
          ? MirrorIssueKind.overflow
          : MirrorIssueKind.error,
      message: message,
    ));
  }

  ResponsiveMirrorController get _controller =>
      widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownController = _createController();
    _nav = MirrorNavigationSync(isEnabled: () => _controller.syncNavigation);
    _scroll = MirrorScrollSync(isEnabled: () => _controller.syncScroll);
    if (kIsWeb) {
      _frame = MirrorFrameConfig.fromUri(Uri.base);
      final frame = _frame;
      if (frame != null) _frameChannel = frameChannel(frame.slotId);
    }
    if (_frame == null && widget.enabled) {
      _setUpIsolated();
      _installErrorHandler();
    }
    _controller.attachExporter(_export);
  }

  // ---------------------------------------------------------------- issues

  void _installErrorHandler() {
    if (_installedOnError != null) return;
    _previousOnError = FlutterError.onError;
    _installedOnError = _onFlutterError;
    FlutterError.onError = _installedOnError;
  }

  void _removeErrorHandler() {
    if (_installedOnError == null) return;
    if (FlutterError.onError == _installedOnError) {
      FlutterError.onError = _previousOnError;
    }
    _installedOnError = null;
    _previousOnError = null;
  }

  void _onFlutterError(FlutterErrorDetails details) {
    try {
      _recordIssue(details);
    } catch (_) {
      // Attribution is best effort; never hide the original error.
    }
    final previous = _previousOnError;
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  }

  void _recordIssue(FlutterErrorDetails details) {
    final slotId = MirrorIssueLocator.slotIdOf(details);
    if (slotId == null || !mounted) return;
    MirrorDevice? device;
    MirrorVariant? variant;
    for (final d in _controller.devices) {
      for (final v in <MirrorVariant?>[null, ..._controller.variants]) {
        if (MirrorSlot.idFor(d, v) == slotId) {
          device = d;
          variant = v;
        }
      }
    }
    if (device == null) return;
    final message = details.exceptionAsString().split('\n').first.trim();
    final issue = MirrorIssue(
      slotId: slotId,
      deviceName: device.name,
      variantLabel: variant?.label,
      kind: message.contains('overflowed')
          ? MirrorIssueKind.overflow
          : MirrorIssueKind.error,
      message: message,
      details: details,
    );
    final controller = _controller;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Errors are often reported during layout/paint: notify after the frame.
      SchedulerBinding.instance
          .addPostFrameCallback((_) => controller.reportIssue(issue));
    } else {
      controller.reportIssue(issue);
    }
  }

  // ---------------------------------------------------------------- export

  Future<List<MirrorExport>> _export({required bool perDevice}) async {
    final exports = <MirrorExport>[];
    if (perDevice) {
      for (final entry in _boundaryKeys.entries) {
        final device = _deviceOf(entry.key);
        final bytes = await _capturePng(
            entry.key, (device?.devicePixelRatio ?? 1).clamp(1, 3).toDouble());
        if (bytes == null) continue;
        exports.add(MirrorExport(
          fileName:
              'responsive_mirror_${entry.key.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.png',
          bytes: bytes,
          slotId: entry.key,
        ));
      }
    } else {
      final bytes = await _renderSheet();
      if (bytes != null) {
        exports.add(
            MirrorExport(fileName: 'responsive_mirror_grid.png', bytes: bytes));
      }
    }
    return exports;
  }

  /// PNG of one device. In isolated mode the device is another page (an
  /// iframe), so its agent renders the PNG and sends it back.
  Future<Uint8List?> _capturePng(String id, double pixelRatio) async {
    final relay = _relay;
    if (relay != null) return relay.capture(id, pixelRatio);
    final boundary = _boundaryKeys[id]?.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  Future<ui.Image?> _captureImage(String id, double pixelRatio) async {
    if (_relay == null) {
      final boundary = _boundaryKeys[id]?.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      return boundary.toImage(pixelRatio: pixelRatio);
    }
    final bytes = await _capturePng(id, pixelRatio);
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Renders the whole matrix as one image, built from per-device captures
  /// (so devices scrolled off screen are included and nothing is clipped).
  Future<Uint8List?> _renderSheet() async {
    final devices = _controller.visibleDevices;
    if (devices.isEmpty) return null;
    final variants = _controller.visibleVariants;
    final rows = variants.isEmpty ? <MirrorVariant?>[null] : variants;
    const s = 0.5, margin = 48.0, gap = 40.0, label = 44.0;
    final header = variants.isEmpty ? 0.0 : 56.0;
    final rowWidth = devices.fold<double>(0, (w, d) => w + d.size.width * s) +
        gap * (devices.length - 1);
    final rowHeight =
        devices.map((d) => d.size.height * s).reduce(math.max) + label;
    final width = (rowWidth + margin * 2).ceil();
    final height = (margin * 2 +
            rows.length * (header + rowHeight) +
            (rows.length - 1) * gap)
        .ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = widget.backgroundColor);

    void text(String value, Offset at, double size, Color color,
        {FontWeight weight = FontWeight.w600, double maxWidth = 2000}) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        fontSize: size,
        fontWeight: weight,
        maxLines: 1,
        ellipsis: '…',
      ))
        ..pushStyle(ui.TextStyle(color: color))
        ..addText(value);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: maxWidth));
      canvas.drawParagraph(paragraph, at);
    }

    var y = margin;
    for (final variant in rows) {
      if (variant != null) {
        final dir = variant.resolvedTextDirection;
        text(
          '${variant.label}${dir == null ? '' : dir == TextDirection.rtl ? '   RTL' : '   LTR'}',
          Offset(margin, y + 8),
          26,
          Colors.white,
        );
        y += header;
      }
      var x = margin;
      for (final device in devices) {
        final id = MirrorSlot.idFor(device, variant);
        final w = device.size.width * s, h = device.size.height * s;
        text('${device.name}   ${device.specLabel}', Offset(x, y + 6), 20,
            Colors.white70,
            weight: FontWeight.w500, maxWidth: math.max(w, 200));
        final rect = Rect.fromLTWH(x, y + label, w, h);
        final rrect = RRect.fromRectAndRadius(
            rect, Radius.circular(device.cornerRadius * s));
        final image = await _captureImage(id, s);
        if (image != null) {
          canvas.save();
          canvas.clipRRect(rrect);
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
                0, 0, image.width.toDouble(), image.height.toDouble()),
            rect,
            Paint()..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
          image.dispose();
        }
        final issues = _controller.issuesFor(id);
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = issues.isEmpty ? 2 : 4
            ..color = issues.isEmpty
                ? const Color(0xFF3A3A44)
                : const Color(0xFFE5484D),
        );
        x += w + gap;
      }
      y += rowHeight + gap;
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  MirrorDevice? _deviceOf(String slotId) {
    for (final d in _controller.devices) {
      if (slotId == d.id || slotId.endsWith('/${d.id}')) return d;
    }
    return null;
  }

  Future<void> _exportFromToolbar({required bool perDevice}) async {
    final exports = await _export(perDevice: perDevice);
    final onExport = widget.onExport;
    String message;
    if (onExport != null) {
      await onExport(exports);
      message =
          'Exported ${exports.length} PNG${exports.length == 1 ? '' : 's'}';
    } else {
      final paths = <String>[];
      for (final e in exports) {
        final path = await savePng(e.fileName, e.bytes);
        if (path != null) paths.add(path);
      }
      message = paths.isEmpty
          ? 'Exported ${exports.length} PNG(s) (no file system here: use onExport)'
          : 'Saved ${paths.length} PNG${paths.length == 1 ? '' : 's'}: ${paths.length == 1 ? paths.first : paths.first.substring(0, paths.first.lastIndexOf(RegExp(r'[\\/]')) + 1)}';
    }
    _messengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      width: 560,
    ));
  }

  ResponsiveMirrorController _createController() => ResponsiveMirrorController(
        devices: widget.devices,
        variants: widget.variants,
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
    if (_ownController != null &&
        !listEquals(widget.variants, oldWidget.variants)) {
      _ownController!.variants = widget.variants;
    }
    oldWidget.controller?.attachExporter(null);
    _controller.attachExporter(_export);
    if (widget.enabled) {
      _installErrorHandler();
    } else {
      _removeErrorHandler();
    }
  }

  @override
  void dispose() {
    _removeErrorHandler();
    _transport?.dispose();
    _relay?.dispose();
    widget.controller?.attachExporter(null);
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
    final frame = _frame;
    final channel = _frameChannel;
    if (frame != null && channel != null) {
      // This copy runs inside a mirror frame (isolated mode).
      final slot = frame.toSlot(_frameObserver);
      return ResponsiveMirrorAgent(
        slot: slot,
        channel: channel,
        child: Builder(builder: (context) => _buildApp(context, slot)),
      );
    }
    if (!widget.enabled) return _buildApp(context, null);
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _relay]),
      builder: (context, _) {
        if (!_controller.mirrorVisible) return _buildSingle(context);
        return MaterialApp(
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          title: 'responsive_mirror',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF6C7BFF),
          ),
          home: Scaffold(
            backgroundColor: widget.backgroundColor,
            body: LayoutBuilder(builder: (context, constraints) {
              final toolbarHeight = widget.showToolbar ? 56.0 : 0.0;
              final variants = _controller.visibleVariants.length;
              _lastFitScale = _fitScale(
                _controller.visibleDevices,
                Size(constraints.maxWidth,
                    constraints.maxHeight - toolbarHeight),
                variants == 0 ? 1 : variants,
              );
              return Column(
                children: [
                  if (widget.showToolbar)
                    MirrorToolbar(
                      controller: _controller,
                      fitScale: () => _lastFitScale,
                      onExport: _exportFromToolbar,
                    ),
                  Expanded(
                    child: Row(children: [
                      Expanded(child: _buildCanvas()),
                      if (_controller.showIssues)
                        MirrorIssuesPanel(controller: _controller),
                    ]),
                  ),
                ],
              );
            }),
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

  static const double _sectionHeader = 36;

  double _fitScale(List<MirrorDevice> devices, Size available, int sections) {
    if (devices.isEmpty) return 0.4;
    final width = available.width - _padding * 2;
    final height = available.height - _padding * 2;
    final sectionExtra = sections > 1 ? _sectionHeader + _spacing : 0.0;

    // Height of one section (a Wrap of device tiles) at [scale].
    double? sectionHeight(double scale) {
      var rowWidth = 0.0, rowHeight = 0.0, total = 0.0;
      var rows = 0;
      for (final device in devices) {
        final size = MirrorDeviceFrame.outerSize(device, scale);
        final tileHeight = size.height + _labelHeight;
        if (size.width > width) return null;
        if (rowWidth > 0 && rowWidth + _spacing + size.width > width) {
          total += rowHeight;
          rows++;
          rowWidth = 0;
          rowHeight = 0;
        }
        rowWidth += (rowWidth > 0 ? _spacing : 0) + size.width;
        rowHeight = math.max(rowHeight, tileHeight);
      }
      total += rowHeight;
      return total + rows * _spacing + sectionExtra;
    }

    double best(int fitSections) {
      for (var scale = 1.0; scale > 0.08; scale -= 0.01) {
        final h = sectionHeight(scale);
        if (h != null && h * fitSections <= height) return scale;
      }
      return 0.08;
    }

    // Try to fit every variant row on screen; if that makes the devices too
    // small, fit one row and let the canvas scroll vertically.
    final all = best(sections);
    if (sections > 1 && all < 0.2) return best(1);
    return all;
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
      final variants = _controller.visibleVariants;
      final sections = variants.isEmpty ? <MirrorVariant?>[null] : variants;
      final scale = _controller.zoom ?? _lastFitScale;
      final widest =
          devices.map((d) => d.size.width * scale + 40).reduce(math.max);
      final contentWidth =
          math.max(constraints.maxWidth - _padding * 2, widest);
      Widget section(MirrorVariant? variant) {
        final wrap = Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (final device in devices) _tile(device, variant, scale),
          ],
        );
        if (variant == null) return wrap;
        return Padding(
          key: ValueKey('rm_section_${variant.id}'),
          padding: const EdgeInsets.only(bottom: _spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _sectionHeader,
                child: Row(children: [
                  _VariantBadge(variant: variant),
                  const SizedBox(width: 12),
                  const Expanded(child: Divider(color: Colors.white12)),
                ]),
              ),
              wrap,
            ],
          ),
        );
      }

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
                child: RepaintBoundary(
                  key: _gridKey,
                  child: ColoredBox(
                    color: widget.backgroundColor,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: contentWidth,
                        maxWidth: contentWidth,
                        minHeight:
                            math.max(0, constraints.maxHeight - _padding * 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final v in sections) section(v)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _tile(MirrorDevice device, MirrorVariant? variant, double scale) {
    final id = MirrorSlot.idFor(device, variant);
    return _DeviceTile(
      key: ValueKey(id),
      device: device,
      scale: scale,
      issues: _controller.issuesFor(id),
      outOfSync: _relay?.outOfSync[id],
      onOutOfSyncTap: () => _relay?.resetSync(),
      frame: _isolatedHost
          ? _transport!.frameView(
              id,
              MirrorFrameConfig(slotId: id, device: device, variant: variant)
                  .applyTo(widget.isolatedUrl ?? Uri.base),
            )
          : null,
      onIssuesTap: () => _controller.showIssues = true,
      boundaryKey: _boundaryKeys.putIfAbsent(
          id, () => GlobalKey(debugLabel: 'responsive_mirror $id')),
      slot: MirrorSlot(
        id: id,
        device: device,
        variant: variant,
        navigatorObserver: _nav.observerFor(id),
      ),
      nav: _nav,
      scroll: _scroll,
      appBuilder: _buildApp,
    );
  }
}

class _VariantBadge extends StatelessWidget {
  const _VariantBadge({required this.variant});

  final MirrorVariant variant;

  @override
  Widget build(BuildContext context) {
    final dir = variant.resolvedTextDirection;
    final icons = <IconData>[
      if (variant.locale != null) Icons.translate,
      if (variant.themeMode == ThemeMode.dark) Icons.dark_mode,
      if (variant.themeMode == ThemeMode.light) Icons.light_mode,
      if (variant.textScale != null) Icons.format_size,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF232838),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final icon in icons) ...[
          Icon(icon, size: 15, color: const Color(0xFF8C97FF)),
          const SizedBox(width: 6),
        ],
        Text(variant.label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        if (dir != null) ...[
          const SizedBox(width: 8),
          Text(dir == TextDirection.rtl ? 'RTL' : 'LTR',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ]),
    );
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
    required this.boundaryKey,
    this.issues = const [],
    this.onIssuesTap,
    this.outOfSync,
    this.onOutOfSyncTap,
    this.frame,
  });

  final MirrorDevice device;
  final double scale;
  final MirrorSlot slot;
  final MirrorNavigationSync nav;
  final MirrorScrollSync scroll;
  final MirrorAppBuilder appBuilder;
  final GlobalKey boundaryKey;
  final List<MirrorIssue> issues;
  final VoidCallback? onIssuesTap;
  final String? outOfSync;
  final VoidCallback? onOutOfSyncTap;
  final Widget? frame;

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
            boundaryKey: boundaryKey,
            frame: frame,
          ),
        ),
      ),
    );
    final count = issues.fold<int>(0, (s, i) => s + i.count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 28,
          // As wide as the frame: badges never change the tile's width, so the
          // grid does not re-flow when a device goes red or out of sync.
          width: MirrorDeviceFrame.outerSize(device, scale).width,
          child: Row(children: [
            Flexible(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            if (outOfSync != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: '$outOfSync (tap to dismiss)',
                child: GestureDetector(
                  onTap: onOutOfSyncTap,
                  child: Container(
                    key: ValueKey('rm_out_of_sync_${slot.id}'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5A524),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sync_problem, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text('out of sync',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
            if (count > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onIssuesTap,
                child: Container(
                  key: ValueKey('rm_issue_badge_${slot.id}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5484D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        MirrorDeviceFrame(
          device: device,
          scale: scale,
          screen: screen,
          highlight: count > 0 ? const Color(0xFFE5484D) : null,
        ),
      ],
    );
  }
}

/// Finds which mirror slot a [FlutterErrorDetails] came from by walking up
/// from the render object or element named in the error to the slot marker.
abstract final class MirrorIssueLocator {
  /// The slot id, or null when the error did not come from a mirrored device.
  static String? slotIdOf(FlutterErrorDetails details) {
    final collector = details.informationCollector;
    if (collector == null) return null;
    for (final node in collector()) {
      final value = node.value;
      if (value is RenderObject) {
        final id = _fromRenderObject(value);
        if (id != null) return id;
      } else if (value is DebugCreator) {
        final id = _fromElement(value.element);
        if (id != null) return id;
      } else if (value is Element) {
        final id = _fromElement(value);
        if (id != null) return id;
      }
    }
    return null;
  }

  static String? _fromRenderObject(RenderObject object) {
    RenderObject? node = object;
    while (node != null) {
      if (node is _RenderSlotMarker) return node.slotId;
      node = node.parent;
    }
    return null;
  }

  static String? _fromElement(Element element) {
    try {
      return element.findAncestorWidgetOfExactType<_SlotMarker>()?.slotId;
    } catch (_) {
      final ro = element.renderObject;
      return ro == null ? null : _fromRenderObject(ro);
    }
  }
}

class _SlotMarker extends SingleChildRenderObjectWidget {
  const _SlotMarker({required this.slotId, super.child});

  final String slotId;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSlotMarker(slotId);

  @override
  void updateRenderObject(
      BuildContext context, _RenderSlotMarker renderObject) {
    renderObject.slotId = slotId;
  }
}

class _RenderSlotMarker extends RenderProxyBox {
  _RenderSlotMarker(this.slotId);

  String slotId;
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
    this.boundaryKey,
    this.frame,
  });

  /// Isolated mode: the frame (iframe view) shown instead of an in-process
  /// copy of the app.
  final Widget? frame;

  /// Key of the [RepaintBoundary] around the app (used for PNG export).
  final GlobalKey? boundaryKey;

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
    final frame = widget.frame;
    if (frame != null) {
      return RepaintBoundary(key: widget.boundaryKey, child: frame);
    }
    var media = slot.device.applyTo(MediaQuery.of(context));
    final variant = slot.variant;
    if (variant != null) media = variant.applyTo(media);
    Widget app = Builder(
      builder: (context) => widget.appBuilder(context, slot),
    );
    final direction = slot.textDirection;
    if (direction != null) {
      app = Directionality(textDirection: direction, child: app);
    }
    return MediaQuery(
      data: media,
      child: MirrorSlotScope(
        slot: slot,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => widget.scroll.handle(slot.id, n),
          child: RepaintBoundary(
            key: widget.boundaryKey,
            child: _SlotMarker(slotId: slot.id, child: app),
          ),
        ),
      ),
    );
  }
}

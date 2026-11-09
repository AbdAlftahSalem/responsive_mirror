import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../slot.dart';
import '../sync/scroll_sync.dart';
import 'protocol.dart';
import 'target.dart';

/// Runs inside one isolated copy of the app (one iframe in isolated mode).
///
/// It reports what the user does here (taps, text input, scrolling) to the
/// mirror host, and replays what the user did on the other copies. Targets
/// are matched by key / semantics label / text, never by coordinates. When a
/// target cannot be found the agent says so and the host marks this device
/// "out of sync".
///
/// `ResponsiveMirror(mode: MirrorMode.isolated, ...)` inserts the agent for
/// you inside each frame; you only use this widget directly with a custom
/// [MirrorChannel] (for example in tests, with [LocalMirrorHub]).
class ResponsiveMirrorAgent extends StatefulWidget {
  /// Creates an agent for [slot] talking over [channel].
  const ResponsiveMirrorAgent({
    super.key,
    required this.slot,
    required this.channel,
    required this.child,
    this.applyMediaQuery = true,
  });

  /// Where this copy runs (device + variant).
  final MirrorSlot slot;

  /// The pipe to the host.
  final MirrorChannel channel;

  /// The app.
  final Widget child;

  /// Whether to apply the slot's safe area / theme / text scale to the
  /// [MediaQuery] (the frame already has the right size).
  final bool applyMediaQuery;

  @override
  State<ResponsiveMirrorAgent> createState() => _ResponsiveMirrorAgentState();
}

class _ResponsiveMirrorAgentState extends State<ResponsiveMirrorAgent> {
  final GlobalKey _rootKey = GlobalKey(debugLabel: 'responsive_mirror agent');
  bool _replaying = false;
  Offset? _downPosition;
  Duration? _downTime;
  MirrorTarget? _downTarget;
  int? _downPointer;
  final Map<ScrollSignature, double> _lastSent = {};
  TextEditingController? _watchedController;
  Element? _watchedField;
  FlutterExceptionHandler? _previousOnError;

  BuildContext? get _root => _rootKey.currentContext;

  @override
  void initState() {
    super.initState();
    widget.channel.listen(_onMessage);
    FocusManager.instance.addListener(_onFocusChange);
    _previousOnError = FlutterError.onError;
    FlutterError.onError = _onError;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _send({'type': 'ready'}));
  }

  @override
  void dispose() {
    if (FlutterError.onError == _onError) {
      FlutterError.onError = _previousOnError;
    }
    FocusManager.instance.removeListener(_onFocusChange);
    _watchedController?.removeListener(_onTextChanged);
    widget.channel.close();
    super.dispose();
  }

  void _send(MirrorMessage message) =>
      widget.channel.send({...message, 'from': widget.slot.id});

  void _onError(FlutterErrorDetails details) {
    try {
      _send({
        'type': 'issue',
        'message': details.exceptionAsString().split('\n').first.trim(),
      });
    } catch (_) {}
    final previous = _previousOnError;
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  }

  // ------------------------------------------------------------- recording

  void _onPointerDown(PointerDownEvent event) {
    if (_replaying || _downPointer != null) return;
    final root = _root;
    final box = root?.findRenderObject();
    if (root == null || box is! RenderBox) return;
    _downPointer = event.pointer;
    _downPosition = event.position;
    _downTime = event.timeStamp;
    _downTarget = MirrorTargetFinder.describeTapAt(
        root, box.globalToLocal(event.position));
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_replaying || event.pointer != _downPointer) return;
    final start = _downPosition, startTime = _downTime;
    final target = _downTarget;
    _downPointer = null;
    if (start == null || startTime == null) return;
    final moved = (event.position - start).distance;
    final held = event.timeStamp - startTime;
    if (moved > 18 || held > const Duration(milliseconds: 600)) return;
    _send({
      'type': 'tap',
      'target': (target ?? const MirrorTarget()).toJson(),
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _downPointer) _downPointer = null;
  }

  bool _onScroll(ScrollNotification n) {
    if (_replaying || n is! ScrollUpdateNotification) return false;
    final root = _root;
    final ctx = n.context;
    if (root == null || ctx == null) return false;
    final state = Scrollable.maybeOf(ctx);
    if (state == null) return false;
    final sig = ScrollMatcher.signatureOf(state, root);
    if (sig == null) return false;
    final fraction = ScrollMatcher.fractionOf(n.metrics);
    final last = _lastSent[sig];
    if (last != null && (last - fraction).abs() < 0.002) return false;
    _lastSent[sig] = fraction;
    _send({'type': 'scroll', 'sig': sig.toJson(), 'fraction': fraction});
    return false;
  }

  void _onFocusChange() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    EditableTextState? editable;
    if (ctx != null && ctx.mounted) {
      editable = ctx.findAncestorStateOfType<EditableTextState>();
    }
    final controller = editable?.widget.controller;
    if (identical(controller, _watchedController)) return;
    _watchedController?.removeListener(_onTextChanged);
    _watchedController = controller;
    _watchedField = editable?.context as Element?;
    controller?.addListener(_onTextChanged);
  }

  String? _lastText;

  void _onTextChanged() {
    final controller = _watchedController;
    final field = _watchedField;
    final root = _root;
    if (_replaying || controller == null || field == null || root == null) {
      return;
    }
    if (controller.text == _lastText) return; // selection-only change
    _lastText = controller.text;
    if (!field.mounted) return;
    _send({
      'type': 'text',
      'target': MirrorTargetFinder.describeField(root, field).toJson(),
      'value': controller.text,
    });
  }

  // -------------------------------------------------------------- replaying

  void _onMessage(MirrorMessage message) {
    if (message['type'] != 'replay' || !mounted) return;
    final event = message['event'];
    if (event is! Map) return;
    final e = event.cast<String, Object?>();
    final root = _root;
    if (root == null) return;
    _replaying = true;
    try {
      switch (e['type']) {
        case 'tap':
          final target = MirrorTarget.fromJson(
              (e['target'] as Map).cast<String, Object?>());
          final element = target.isIdentifiable
              ? MirrorTargetFinder.resolveTap(root, target)
              : null;
          if (element == null) {
            _send({'type': 'nomatch', 'what': 'tap $target'});
          } else {
            MirrorTargetFinder.tap(element);
            _send({'type': 'ok'});
          }
        case 'text':
          final target = MirrorTarget.fromJson(
              (e['target'] as Map).cast<String, Object?>());
          final element = MirrorTargetFinder.resolveField(root, target);
          final value = '${e['value'] ?? ''}';
          if (element == null) {
            _send({'type': 'nomatch', 'what': 'text field $target'});
          } else {
            (element.widget as EditableText).controller.value =
                TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
            _send({'type': 'ok'});
          }
        case 'scroll':
          final sig = ScrollSignature.fromJson(
              (e['sig'] as Map).cast<String, Object?>());
          final state = ScrollMatcher.resolve(root, sig);
          if (state != null) {
            ScrollMatcher.applyFraction(
                state, (e['fraction'] as num?)?.toDouble() ?? 0);
          }
      }
    } finally {
      _replaying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    Widget app = KeyedSubtree(key: _rootKey, child: widget.child);
    app = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: app,
    );
    app = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: app,
    );
    final direction = slot.textDirection;
    if (direction != null) {
      app = Directionality(textDirection: direction, child: app);
    }
    app = MirrorSlotScope(slot: slot, child: app);
    if (!widget.applyMediaQuery) return app;
    var media = MediaQuery.of(context).copyWith(
      padding: slot.device.safeArea,
      viewPadding: slot.device.safeArea,
    );
    // Inside a frame the window already has the device size; elsewhere
    // (tests, custom hosts) the slot's size is applied.
    if (!slot.device.size.isEmpty)
      media = media.copyWith(size: slot.device.size);
    final variant = slot.variant;
    if (variant != null) media = variant.applyTo(media);
    return MediaQuery(data: media, child: app);
  }
}

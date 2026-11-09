import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Describes a scrollable in a way that can be found again in another copy of
/// the same app: its axis, its nearest [ValueKey] (if any) and its position
/// among the visible scrollables with the same axis.
@immutable
class ScrollSignature {
  /// Creates a signature.
  const ScrollSignature({required this.axis, required this.ordinal, this.key});

  /// Scroll axis.
  final Axis axis;

  /// Index among visible scrollables with the same axis, in tree order.
  final int ordinal;

  /// `toString()` of the nearest [ValueKey] around the scrollable, if any.
  final String? key;

  /// Serialises the signature (used by isolated mode).
  Map<String, Object?> toJson() =>
      {'axis': axis.name, 'ordinal': ordinal, 'key': key};

  /// Reads a signature written by [toJson].
  static ScrollSignature fromJson(Map<String, Object?> json) => ScrollSignature(
        axis: json['axis'] == 'horizontal' ? Axis.horizontal : Axis.vertical,
        ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
        key: json['key'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ScrollSignature &&
      other.axis == axis &&
      other.ordinal == ordinal &&
      other.key == key;

  @override
  int get hashCode => Object.hash(axis, ordinal, key);

  @override
  String toString() => 'ScrollSignature($axis #$ordinal key=$key)';
}

/// Finds scrollables inside one copy of the app and moves them.
///
/// This is pure tree inspection, shared by the in-process mirror and by the
/// isolated-mode agent.
abstract final class ScrollMatcher {
  /// How far up from a [Scrollable] to look for a [ValueKey].
  static const int keySearchDepth = 6;

  /// Scrollables under [root] that are actually on screen (hit-testable at
  /// their centre), in tree order.
  static List<ScrollableState> visibleScrollables(BuildContext root) {
    final rootBox = root.findRenderObject();
    if (rootBox is! RenderBox || !rootBox.hasSize || !rootBox.attached) {
      return const [];
    }
    final result = <ScrollableState>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (_isVisible(state, rootBox)) result.add(state);
      }
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
    return result;
  }

  static bool _isVisible(ScrollableState state, RenderBox rootBox) {
    final box = state.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    if (box.size.isEmpty) return false;
    final Offset center;
    try {
      center =
          box.localToGlobal(box.size.center(Offset.zero), ancestor: rootBox);
    } catch (_) {
      return false;
    }
    final hit = BoxHitTestResult();
    if (!rootBox.hitTest(hit, position: center)) return false;
    for (final entry in hit.path) {
      if (identical(entry.target, box)) return true;
    }
    return false;
  }

  /// The nearest [ValueKey] on [state]'s widget or a close ancestor.
  static String? keyOf(ScrollableState state) {
    String? found;
    final own = state.widget.key;
    if (own is ValueKey) return own.value.toString();
    var depth = 0;
    state.context.visitAncestorElements((ancestor) {
      final key = ancestor.widget.key;
      if (key is ValueKey && key.value is! Enum) {
        found = key.value.toString();
        return false;
      }
      return ++depth < keySearchDepth;
    });
    return found;
  }

  /// Signature of [state] relative to [root].
  static ScrollSignature? signatureOf(
      ScrollableState state, BuildContext root) {
    final axis = axisDirectionToAxis(state.axisDirection);
    final same = visibleScrollables(root)
        .where((s) => axisDirectionToAxis(s.axisDirection) == axis)
        .toList();
    final ordinal = same.indexOf(state);
    return ScrollSignature(
      axis: axis,
      ordinal: ordinal < 0 ? 0 : ordinal,
      key: keyOf(state),
    );
  }

  /// Finds the scrollable matching [signature] under [root]: same key first,
  /// then the same position among visible scrollables of that axis.
  static ScrollableState? resolve(
      BuildContext root, ScrollSignature signature) {
    final same = visibleScrollables(root)
        .where((s) => axisDirectionToAxis(s.axisDirection) == signature.axis)
        .toList();
    if (same.isEmpty) return null;
    if (signature.key != null) {
      for (final s in same) {
        if (keyOf(s) == signature.key) return s;
      }
    }
    if (signature.ordinal < same.length) return same[signature.ordinal];
    return null;
  }

  /// How far [position] is scrolled, from 0 (start) to 1 (end).
  static double fractionOf(ScrollMetrics position) {
    if (!position.hasContentDimensions) return 0;
    final range = position.maxScrollExtent - position.minScrollExtent;
    if (range <= 0) return 0;
    return ((position.pixels - position.minScrollExtent) / range)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Jumps [state] to [fraction] of its scroll range.
  static void applyFraction(ScrollableState state, double fraction) {
    final position = state.position;
    if (!position.hasContentDimensions) return;
    final target = position.minScrollExtent +
        (position.maxScrollExtent - position.minScrollExtent) * fraction;
    if ((position.pixels - target).abs() < 0.5) return;
    position.jumpTo(target);
  }
}

/// Mirrors scrolling between the devices of an in-process mirror.
class MirrorScrollSync {
  /// Creates the hub. [isEnabled] is read on every notification.
  MirrorScrollSync({required this.isEnabled});

  /// Whether scroll mirroring is on.
  final bool Function() isEnabled;

  final Map<String, BuildContext> _roots = {};
  bool _applying = false;

  /// Registers the root context of a device.
  void register(String slotId, BuildContext root) => _roots[slotId] = root;

  /// Forgets a device.
  void unregister(String slotId, BuildContext root) {
    if (identical(_roots[slotId], root)) _roots.remove(slotId);
  }

  /// Feed every [ScrollNotification] of slot [slotId] here.
  /// Always returns false so the notification keeps bubbling.
  bool handle(String slotId, ScrollNotification notification) {
    if (_applying || !isEnabled()) return false;
    if (notification is! ScrollUpdateNotification) return false;
    final source = _roots[slotId];
    final ctx = notification.context;
    if (source == null || ctx == null || !ctx.mounted) return false;
    final state = Scrollable.maybeOf(ctx);
    if (state == null) return false;
    final signature = ScrollMatcher.signatureOf(state, source);
    if (signature == null) return false;
    final fraction = ScrollMatcher.fractionOf(notification.metrics);
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Never move other render objects in the middle of layout.
      SchedulerBinding.instance
          .addPostFrameCallback((_) => _apply(slotId, signature, fraction));
    } else {
      _apply(slotId, signature, fraction);
    }
    return false;
  }

  void _apply(String slotId, ScrollSignature signature, double fraction) {
    _applying = true;
    try {
      for (final entry in _roots.entries) {
        if (entry.key == slotId || !entry.value.mounted) continue;
        final target = ScrollMatcher.resolve(entry.value, signature);
        if (target != null) ScrollMatcher.applyFraction(target, fraction);
      }
    } finally {
      _applying = false;
    }
  }
}

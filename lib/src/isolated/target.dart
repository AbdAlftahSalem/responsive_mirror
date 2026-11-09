import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// How a tapped (or edited) widget is described so the same widget can be
/// found in another, independent copy of the app.
///
/// Coordinates are never used: devices have different layouts. A target is
/// matched by its [ValueKey], its semantics label / tooltip, its text and
/// finally its position among identical candidates ([ordinal]).
@immutable
class MirrorTarget {
  /// Creates a target description.
  const MirrorTarget({
    this.key,
    this.label,
    this.text,
    this.type,
    this.ordinal = 0,
  });

  /// `toString()` of the nearest [ValueKey] value.
  final String? key;

  /// Semantics label, tooltip, or input decoration label/hint.
  final String? label;

  /// Visible text inside the target.
  final String? text;

  /// Runtime type of the widget that owns the gesture, e.g. `InkWell`.
  final String? type;

  /// Index among visible candidates with the same key/label/text.
  final int ordinal;

  /// Whether anything identifying was found.
  bool get isIdentifiable => key != null || label != null || text != null;

  /// Serialises the target.
  Map<String, Object?> toJson() => {
        'key': key,
        'label': label,
        'text': text,
        'type': type,
        'ordinal': ordinal,
      };

  /// Reads a target written by [toJson].
  static MirrorTarget fromJson(Map<String, Object?> json) => MirrorTarget(
        key: json['key'] as String?,
        label: json['label'] as String?,
        text: json['text'] as String?,
        type: json['type'] as String?,
        ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      );

  bool _sameIdentity(MirrorTarget other) =>
      key == other.key && label == other.label && text == other.text;

  @override
  String toString() {
    final parts = [
      if (key != null) 'key=$key',
      if (label != null) 'label="$label"',
      if (text != null) 'text="$text"',
      if (ordinal > 0) '#$ordinal',
    ];
    return parts.isEmpty ? 'unidentified ${type ?? 'widget'}' : parts.join(' ');
  }
}

/// Finds tappable widgets and text fields in a widget tree and describes them
/// as [MirrorTarget]s; resolves a [MirrorTarget] back to a widget in another
/// copy of the app; synthesises taps.
abstract final class MirrorTargetFinder {
  /// How far up from a gesture detector to look for a key or a label.
  static const int ancestorDepth = 10;

  static bool _isTappable(Element e) {
    final widget = e.widget;
    if (widget is RawGestureDetector) {
      return widget.gestures.keys.any((t) =>
          t == TapGestureRecognizer ||
          t == LongPressGestureRecognizer ||
          t == DoubleTapGestureRecognizer);
    }
    return false;
  }

  static bool _isOnScreen(Element e, RenderBox rootBox) {
    final box = e.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return false;
    }
    final Offset center;
    try {
      center =
          box.localToGlobal(box.size.center(Offset.zero), ancestor: rootBox);
    } catch (_) {
      return false;
    }
    final hit = BoxHitTestResult();
    if (!rootBox.hitTest(hit, position: center)) return false;
    return hit.path.any((entry) => identical(entry.target, box));
  }

  static String? _keyOf(Element element) {
    String? found;
    var depth = 0;
    bool check(Element e) {
      final key = e.widget.key;
      if (key is ValueKey && (key.value is String || key.value is num)) {
        found = key.value.toString();
        return false;
      }
      return ++depth < ancestorDepth;
    }

    if (check(element)) element.visitAncestorElements(check);
    return found;
  }

  static String? _labelOf(Element element) {
    String? found;
    var depth = 0;
    bool check(Element e) {
      final w = e.widget;
      if (w is Semantics && (w.properties.label?.isNotEmpty ?? false)) {
        found = w.properties.label;
      } else if (w is Tooltip && (w.message?.isNotEmpty ?? false)) {
        found = w.message;
      } else if (w is InputDecorator) {
        found = w.decoration.labelText ?? w.decoration.hintText;
      } else if (w is TextField) {
        found = w.decoration?.labelText ?? w.decoration?.hintText;
      }
      if (found != null) return false;
      return ++depth < ancestorDepth;
    }

    if (check(element)) element.visitAncestorElements(check);
    if (found != null) return found;
    // Labels below the gesture detector (e.g. Semantics inside a button).
    void down(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is Semantics && (w.properties.label?.isNotEmpty ?? false)) {
        found = w.properties.label;
        return;
      }
      if (w is Tooltip && (w.message?.isNotEmpty ?? false)) {
        found = w.message;
        return;
      }
      e.visitChildren(down);
    }

    element.visitChildren(down);
    return found;
  }

  static String? _textOf(Element element) {
    final parts = <String>[];
    void visit(Element e) {
      final w = e.widget;
      if (w is RichText) {
        final t = w.text.toPlainText().trim();
        if (t.isNotEmpty) parts.add(t);
        return;
      }
      if (w is EditableText) return;
      e.visitChildren(visit);
    }

    visit(element);
    if (parts.isEmpty) return null;
    final text = parts.join(' ');
    return text.length > 120 ? text.substring(0, 120) : text;
  }

  static MirrorTarget _describe(Element e, {int ordinal = 0}) => MirrorTarget(
        key: _keyOf(e),
        label: _labelOf(e),
        text: _textOf(e),
        type: _ownerType(e),
        ordinal: ordinal,
      );

  static String? _ownerType(Element e) {
    String? type;
    var depth = 0;
    e.visitAncestorElements((a) {
      final name = a.widget.runtimeType.toString();
      if (!name.startsWith('_') &&
          name != 'GestureDetector' &&
          name != 'Semantics' &&
          name != 'MouseRegion' &&
          name != 'Listener') {
        type = name;
        return false;
      }
      return ++depth < 4;
    });
    return type;
  }

  /// Visible tappable elements under [root], in tree order.
  static List<Element> tappables(BuildContext root) =>
      _collect(root, _isTappable);

  /// Visible [EditableText] elements under [root], in tree order.
  static List<Element> textFields(BuildContext root) =>
      _collect(root, (e) => e.widget is EditableText);

  static List<Element> _collect(
      BuildContext root, bool Function(Element) test) {
    final rootBox = root.findRenderObject();
    if (rootBox is! RenderBox || !rootBox.hasSize) return const [];
    final out = <Element>[];
    void visit(Element e) {
      if (test(e) && _isOnScreen(e, rootBox)) out.add(e);
      e.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
    return out;
  }

  static MirrorTarget _withOrdinal(Element e, List<Element> candidates) {
    final base = _describe(e);
    var ordinal = 0;
    for (final c in candidates) {
      if (identical(c, e)) break;
      if (_describe(c)._sameIdentity(base)) ordinal++;
    }
    return _describe(e, ordinal: ordinal);
  }

  /// Describes the tappable widget at [position] (in [root]'s coordinates).
  static MirrorTarget? describeTapAt(BuildContext root, Offset position) {
    final rootBox = root.findRenderObject();
    if (rootBox is! RenderBox || !rootBox.hasSize) return null;
    final hit = BoxHitTestResult();
    if (!rootBox.hitTest(hit, position: position)) return null;
    final candidates = tappables(root);
    final byRender = <RenderObject, Element>{
      for (final c in candidates)
        if (c.findRenderObject() != null) c.findRenderObject()!: c,
    };
    // The deepest gesture detector that was hit is the one that wins the tap.
    for (final entry in hit.path) {
      final e = byRender[entry.target];
      if (e != null) return _withOrdinal(e, candidates);
    }
    return null;
  }

  /// Describes the text field whose [EditableText] is [element].
  static MirrorTarget describeField(BuildContext root, Element element) =>
      _withOrdinal(element, textFields(root));

  /// Finds the element matching [target] among [candidates].
  static Element? _resolve(List<Element> candidates, MirrorTarget target) {
    if (candidates.isEmpty) return null;
    int score(MirrorTarget t) {
      var s = 0;
      if (target.key != null && t.key == target.key) s += 4;
      if (target.label != null && t.label == target.label) s += 3;
      if (target.text != null && t.text == target.text) s += 2;
      if (target.key != null && t.key != null && t.key != target.key) s -= 6;
      return s;
    }

    final described = [for (final c in candidates) (c, _describe(c))];
    var best = 0;
    for (final (_, t) in described) {
      final s = score(t);
      if (s > best) best = s;
    }
    if (best < 2) return null;
    final top = [
      for (final (c, t) in described)
        if (score(t) == best) c,
    ];
    if (target.ordinal < top.length) return top[target.ordinal];
    return top.length == 1 ? top.first : null;
  }

  /// Finds the tappable matching [target] under [root].
  static Element? resolveTap(BuildContext root, MirrorTarget target) =>
      _resolve(tappables(root), target);

  /// Finds the text field matching [target] under [root].
  static Element? resolveField(BuildContext root, MirrorTarget target) =>
      _resolve(textFields(root), target);

  static int _pointer = 9000;

  /// Dispatches a synthetic tap at the centre of [element].
  static bool tap(Element element) {
    final box = element.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    final pointer = ++_pointer;
    final binding = GestureBinding.instance;
    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    binding.handlePointerEvent(PointerDownEvent(
      pointer: pointer,
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.touch,
    ));
    binding.handlePointerEvent(PointerUpEvent(
      pointer: pointer,
      position: position,
      timeStamp: now + const Duration(milliseconds: 40),
      kind: PointerDeviceKind.touch,
    ));
    return true;
  }
}

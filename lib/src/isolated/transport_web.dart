import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'protocol.dart';

const String _marker = 'responsive_mirror';

MirrorMessage? _decode(JSAny? data) {
  if (data == null || !data.isA<JSString>()) return null;
  try {
    final decoded = jsonDecode((data as JSString).toDart);
    if (decoded is Map && decoded['rm'] == _marker) {
      return decoded.cast<String, Object?>();
    }
  } catch (_) {}
  return null;
}

JSString _encode(MirrorMessage message) =>
    jsonEncode({...message, 'rm': _marker}).toJS;

/// Host side of isolated mode on the web: one `<iframe>` per device, messages
/// through `window.postMessage`.
class MirrorHostTransport {
  /// Creates the transport; [onMessage] receives every agent message.
  MirrorHostTransport({required this.onMessage}) {
    _listener = ((web.MessageEvent event) {
      final message = _decode(event.data);
      if (message != null) onMessage(message);
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  /// Receives agent messages.
  final void Function(MirrorMessage message) onMessage;
  late final JSFunction _listener;
  final Map<String, web.HTMLIFrameElement> _frames = {};

  /// Whether isolated mode can run on this platform.
  static bool get isSupported => true;

  /// The view that shows the frame of [slotId].
  Widget frameView(String slotId, Uri src) {
    return HtmlElementView.fromTagName(
      key: ValueKey('rm_frame_$slotId|$src'),
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final frame = element as web.HTMLIFrameElement;
        frame.src = src.toString();
        frame.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'white';
        _frames[slotId] = frame;
      },
    );
  }

  /// Sends [message] to the frame of [slotId].
  void send(String slotId, MirrorMessage message) {
    _frames[slotId]?.contentWindow?.postMessage(_encode(message), '*'.toJS);
  }

  /// Forgets the frame of [slotId].
  void remove(String slotId) => _frames.remove(slotId);

  /// Stops listening.
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frames.clear();
  }
}

class _ParentChannel implements MirrorChannel {
  _ParentChannel(this.slotId);

  final String slotId;
  JSFunction? _listener;

  @override
  void send(MirrorMessage message) {
    web.window.parent
        ?.postMessage(_encode({...message, 'from': slotId}), '*'.toJS);
  }

  @override
  void listen(void Function(MirrorMessage message) onMessage) {
    close();
    final listener = ((web.MessageEvent event) {
      final message = _decode(event.data);
      if (message != null) onMessage(message);
    }).toJS;
    _listener = listener;
    web.window.addEventListener('message', listener);
  }

  @override
  void close() {
    final listener = _listener;
    if (listener != null) web.window.removeEventListener('message', listener);
    _listener = null;
  }
}

/// The channel to the host when this app runs inside a mirror frame.
MirrorChannel? frameChannel(String slotId) => _ParentChannel(slotId);

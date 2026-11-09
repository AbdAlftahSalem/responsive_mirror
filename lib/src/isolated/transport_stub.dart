import 'package:flutter/widgets.dart';

import 'protocol.dart';

/// Host side of isolated mode. Only the web has a real implementation
/// (iframes + `postMessage`); elsewhere isolated mode is not available.
class MirrorHostTransport {
  /// Creates the transport; [onMessage] receives every agent message.
  MirrorHostTransport({required this.onMessage});

  /// Receives agent messages.
  final void Function(MirrorMessage message) onMessage;

  /// Whether isolated mode can run on this platform.
  static bool get isSupported => false;

  /// The view that shows the frame of [slotId].
  Widget frameView(String slotId, Uri src) => const SizedBox.shrink();

  /// Sends [message] to the frame of [slotId].
  void send(String slotId, MirrorMessage message) {}

  /// Forgets the frame of [slotId].
  void remove(String slotId) {}

  /// Stops listening.
  void dispose() {}
}

/// The channel to the host when this app runs inside a mirror frame.
MirrorChannel? frameChannel(String slotId) => null;

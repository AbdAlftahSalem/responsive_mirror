import 'dart:async';

import 'package:flutter/material.dart';

import '../device.dart';
import '../slot.dart';
import '../variant.dart';

/// A message between the mirror host and the agents (JSON-compatible map).
typedef MirrorMessage = Map<String, Object?>;

/// A two-way message pipe between one agent (a copy of the app running on
/// its own) and the mirror host.
abstract class MirrorChannel {
  /// Sends [message] to the other side.
  void send(MirrorMessage message);

  /// Registers the handler for incoming messages.
  void listen(void Function(MirrorMessage message) onMessage);

  /// Stops listening.
  void close();
}

/// Host-side logic of isolated mode, independent of the transport: relays
/// what one copy of the app did to every other copy, and tracks which
/// copies could not follow ("out of sync").
class MirrorRelay extends ChangeNotifier {
  /// Creates a relay that delivers messages with [sendTo].
  MirrorRelay({
    required this.sendTo,
    this.isInputSyncEnabled = _always,
    this.isScrollSyncEnabled = _always,
    this.onIssue,
  });

  static bool _always() => true;

  /// Delivers [message] to the agent of [slotId].
  final void Function(String slotId, MirrorMessage message) sendTo;

  /// Whether taps and text input are mirrored.
  final bool Function() isInputSyncEnabled;

  /// Whether scrolling is mirrored.
  final bool Function() isScrollSyncEnabled;

  /// Called when an agent reports a Flutter error.
  final void Function(String slotId, String message)? onIssue;

  final Set<String> _ready = {};
  final Map<String, String> _outOfSync = {};

  /// Slots whose agent is up and listening.
  Set<String> get readySlots => Set.unmodifiable(_ready);

  /// Slots that could not replay the last action, with the reason.
  Map<String, String> get outOfSync => Map.unmodifiable(_outOfSync);

  /// Forgets a slot (its frame was removed).
  void remove(String slotId) {
    _ready.remove(slotId);
    if (_outOfSync.remove(slotId) != null) notifyListeners();
  }

  /// Marks every slot as in sync again.
  void resetSync() {
    if (_outOfSync.isEmpty) return;
    _outOfSync.clear();
    notifyListeners();
  }

  /// Handles a message coming from an agent.
  void receive(MirrorMessage message) {
    final from = message['from'];
    if (from is! String) return;
    switch (message['type']) {
      case 'ready':
        _ready.add(from);
      case 'tap':
      case 'text':
        if (isInputSyncEnabled()) _broadcast(from, message);
      case 'scroll':
        if (isScrollSyncEnabled()) _broadcast(from, message);
      case 'nomatch':
        _outOfSync[from] = '${message['what'] ?? 'action'} not found';
        notifyListeners();
      case 'ok':
        if (_outOfSync.remove(from) != null) notifyListeners();
      case 'issue':
        onIssue?.call(from, '${message['message']}');
    }
  }

  void _broadcast(String from, MirrorMessage event) {
    for (final slot in _ready) {
      if (slot == from) continue;
      sendTo(slot, {'type': 'replay', 'event': event});
    }
  }
}

/// An in-memory host + channels, for tests and for experimenting with the
/// agent without a browser. Messages are delivered asynchronously, like
/// `postMessage`.
class LocalMirrorHub {
  /// Creates a hub with its own [relay].
  LocalMirrorHub() {
    relay = MirrorRelay(sendTo: (slot, message) {
      final channel = _channels[slot];
      if (channel != null) scheduleMicrotask(() => channel._deliver(message));
    });
  }

  /// The relay used by this hub.
  late final MirrorRelay relay;
  final Map<String, _LocalChannel> _channels = {};

  /// The channel an agent for [slotId] should use.
  MirrorChannel channelFor(String slotId) =>
      _channels.putIfAbsent(slotId, () => _LocalChannel(slotId, this));
}

class _LocalChannel implements MirrorChannel {
  _LocalChannel(this.slotId, this.hub);

  final String slotId;
  final LocalMirrorHub hub;
  void Function(MirrorMessage message)? _onMessage;

  void _deliver(MirrorMessage message) => _onMessage?.call(message);

  @override
  void send(MirrorMessage message) {
    final copy = {...message, 'from': slotId};
    scheduleMicrotask(() => hub.relay.receive(copy));
  }

  @override
  void listen(void Function(MirrorMessage message) onMessage) =>
      _onMessage = onMessage;

  @override
  void close() => _onMessage = null;
}

/// What a frame (one isolated copy of the app) needs to know about itself,
/// passed through its URL query (`rm_*` parameters).
@immutable
class MirrorFrameConfig {
  /// Creates a config.
  const MirrorFrameConfig(
      {required this.slotId, required this.device, this.variant});

  /// Slot id of this frame.
  final String slotId;

  /// The device this frame plays.
  final MirrorDevice device;

  /// The variant (locale / theme / text scale), if any.
  final MirrorVariant? variant;

  /// The [MirrorSlot] the app inside the frame sees.
  MirrorSlot toSlot(NavigatorObserver observer) => MirrorSlot(
        id: slotId,
        device: device,
        variant: variant,
        navigatorObserver: observer,
      );

  /// Adds this config to [base] as `rm_*` query parameters.
  Uri applyTo(Uri base) {
    final pad = device.safeArea;
    final v = variant;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
      queryParameters: {
        ...base.queryParameters,
        'rm_frame': slotId,
        'rm_device': device.id,
        'rm_name': device.name,
        'rm_size': '${device.size.width.round()}x${device.size.height.round()}',
        'rm_pad': '${pad.left},${pad.top},${pad.right},${pad.bottom}',
        'rm_platform': device.platform.name,
        if (v != null) 'rm_variant': v.id,
        if (v != null) 'rm_variant_label': v.label,
        if (v?.locale != null) 'rm_locale': v!.locale!.toLanguageTag(),
        if (v?.themeMode != null) 'rm_theme': v!.themeMode!.name,
        if (v?.textScale != null) 'rm_text': '${v!.textScale}',
      },
    );
  }

  /// Reads the config from a frame URL, or null when [uri] is not a frame.
  static MirrorFrameConfig? fromUri(Uri uri) {
    final q = uri.queryParameters;
    final slotId = q['rm_frame'];
    if (slotId == null) return null;
    final size =
        (q['rm_size'] ?? '0x0').split('x').map(double.tryParse).toList();
    final pad =
        (q['rm_pad'] ?? '0,0,0,0').split(',').map(double.tryParse).toList();
    final device = MirrorDevice(
      id: q['rm_device'] ?? slotId,
      name: q['rm_name'] ?? slotId,
      size: Size(size.first ?? 0, size.length > 1 ? size[1] ?? 0 : 0),
      safeArea: pad.length == 4
          ? EdgeInsets.fromLTRB(
              pad[0] ?? 0, pad[1] ?? 0, pad[2] ?? 0, pad[3] ?? 0)
          : EdgeInsets.zero,
      platform: TargetPlatform.values.firstWhere(
        (p) => p.name == q['rm_platform'],
        orElse: () => TargetPlatform.android,
      ),
    );
    MirrorVariant? variant;
    if (q['rm_variant'] != null) {
      final tag = q['rm_locale'];
      final parts = tag?.split('-');
      variant = MirrorVariant(
        id: q['rm_variant']!,
        label: q['rm_variant_label'] ?? q['rm_variant']!,
        locale: parts == null
            ? null
            : Locale(parts.first, parts.length > 1 ? parts[1] : null),
        themeMode:
            ThemeMode.values.where((m) => m.name == q['rm_theme']).firstOrNull,
        textScale: double.tryParse(q['rm_text'] ?? ''),
      );
    }
    return MirrorFrameConfig(slotId: slotId, device: device, variant: variant);
  }
}

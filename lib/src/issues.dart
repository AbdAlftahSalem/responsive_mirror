import 'package:flutter/foundation.dart';

/// What kind of problem a device reported.
enum MirrorIssueKind {
  /// A RenderFlex (Row/Column/Flex) or other layout overflow.
  overflow,

  /// Any other Flutter error (exception during build, layout or paint).
  error,
}

/// One problem caught on one device (and variant) of the mirror.
@immutable
class MirrorIssue {
  /// Creates an issue.
  const MirrorIssue({
    required this.slotId,
    required this.deviceName,
    required this.kind,
    required this.message,
    this.variantLabel,
    this.count = 1,
    this.details,
  });

  /// The slot (device × variant) the issue happened in.
  final String slotId;

  /// Name of the device.
  final String deviceName;

  /// Label of the variant, if the mirror uses variants.
  final String? variantLabel;

  /// Overflow or other error.
  final MirrorIssueKind kind;

  /// First line of the error, e.g. "A RenderFlex overflowed by 85 pixels on
  /// the right."
  final String message;

  /// How many times the same message was reported on this slot.
  final int count;

  /// The original error details, when available.
  final FlutterErrorDetails? details;

  /// Where the issue happened, e.g. "iPhone SE · العربية".
  String get where =>
      variantLabel == null ? deviceName : '$deviceName · $variantLabel';

  /// Returns this issue with [count] increased by one.
  MirrorIssue repeated() => MirrorIssue(
        slotId: slotId,
        deviceName: deviceName,
        kind: kind,
        message: message,
        variantLabel: variantLabel,
        count: count + 1,
        details: details,
      );

  @override
  String toString() => '[$where] $message${count > 1 ? ' (×$count)' : ''}';
}

/// A PNG produced by the mirror's export.
@immutable
class MirrorExport {
  /// Creates an export.
  const MirrorExport({
    required this.fileName,
    required this.bytes,
    this.slotId,
  });

  /// Suggested file name, e.g. `responsive_mirror_iphone_15.png`.
  final String fileName;

  /// PNG bytes.
  final Uint8List bytes;

  /// The slot this image shows, or null for the whole grid.
  final String? slotId;
}

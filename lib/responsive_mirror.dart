/// Preview your Flutter app on many devices at once: phones, tablets,
/// laptops and desktops side by side, with navigation and scrolling in sync.
library;

export 'src/controller.dart';
export 'src/device.dart';
export 'src/isolated/agent.dart';
export 'src/isolated/protocol.dart';
export 'src/isolated/target.dart';
export 'src/issues.dart';
export 'src/slot.dart';
export 'src/sync/navigation_sync.dart'
    show MirrorNavigationSync, MirrorNavigatorObserver;
export 'src/variant.dart';
export 'src/sync/scroll_sync.dart'
    show MirrorScrollSync, ScrollMatcher, ScrollSignature;
export 'src/widgets/device_frame.dart';
export 'src/widgets/issues_panel.dart';
export 'src/widgets/responsive_mirror.dart';
export 'src/widgets/toolbar.dart';

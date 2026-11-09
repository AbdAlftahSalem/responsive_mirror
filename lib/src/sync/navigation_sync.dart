import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A [NavigatorObserver] attached to one device's navigator.
///
/// It keeps its own copy of the page stack (only [PageRoute]s; dialogs and
/// popups stay local to the device they were opened on) and reports every
/// change to the [MirrorNavigationSync] hub, which replays it on the others.
class MirrorNavigatorObserver extends NavigatorObserver {
  /// Creates an observer for the slot [slotId].
  MirrorNavigatorObserver(this.slotId, this._hub);

  /// The slot this observer belongs to.
  final String slotId;
  final MirrorNavigationSync _hub;

  /// The page routes currently on this device's navigator, bottom first.
  final List<Route<dynamic>> pages = <Route<dynamic>>[];

  bool _ready = false;
  bool _readyScheduled = false;

  /// True once the navigator finished pushing its initial route(s).
  bool get isReady => _ready;

  void _ensureReadyScheduled() {
    if (_readyScheduled) return;
    _readyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ready = true;
      _hub._onObserverReady(this);
    });
  }

  static bool _tracked(Route<dynamic> route) => route is PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _ensureReadyScheduled();
    if (!_tracked(route)) return;
    pages.add(route);
    if (_ready) _hub._broadcastPush(this, route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final index = pages.indexOf(route);
    if (index < 0) return;
    pages.removeAt(index);
    if (_ready) _hub._broadcastRemove(this, index, popped: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final index = pages.indexOf(route);
    if (index < 0) return;
    pages.removeAt(index);
    if (_ready) _hub._broadcastRemove(this, index, popped: false);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null || newRoute == null) return;
    final index = pages.indexOf(oldRoute);
    if (index < 0) return;
    if (_tracked(newRoute)) {
      pages[index] = newRoute;
      if (_ready) _hub._broadcastReplace(this, index, newRoute);
    } else {
      pages.removeAt(index);
      if (_ready) _hub._broadcastRemove(this, index, popped: false);
    }
  }
}

/// Keeps the navigators of every device in step.
///
/// Every device has its own [Navigator] (its own copy of your `MaterialApp`).
/// When a page is pushed, popped, removed or replaced on one of them, the hub
/// replays the same change on the others, matching pages by their position in
/// the stack. Routes are re-created from their builder ([MaterialPageRoute],
/// [CupertinoPageRoute], [PageRouteBuilder]) or, for other route types, pushed
/// again by name through the target navigator's own route table.
class MirrorNavigationSync {
  /// Creates a hub. [isEnabled] is read on every event.
  MirrorNavigationSync({required this.isEnabled, this.onOutOfSync});

  /// Whether replaying is currently on.
  final bool Function() isEnabled;

  /// Called when a change could not be replayed on a slot.
  final void Function(String slotId, String reason)? onOutOfSync;

  final Map<String, MirrorNavigatorObserver> _observers = {};
  bool _replaying = false;

  /// Observers currently registered, by slot id.
  Map<String, MirrorNavigatorObserver> get observers =>
      Map.unmodifiable(_observers);

  /// Returns (and remembers) the observer for [slotId].
  MirrorNavigatorObserver observerFor(String slotId) => _observers.putIfAbsent(
      slotId, () => MirrorNavigatorObserver(slotId, this));

  /// The page stack of the last device that left, used to bring new
  /// devices to the same page when every device was replaced at once
  /// (for example when variants are switched on).
  List<Route<dynamic>>? _lastKnownPages;

  /// Forgets [slotId] (called when its device is removed from the grid).
  void unregister(String slotId) {
    final observer = _observers.remove(slotId);
    if (observer != null) {
      _lastKnownPages =
          observer.pages.length > 1 ? List.of(observer.pages) : null;
    }
  }

  Iterable<MirrorNavigatorObserver> _targets(MirrorNavigatorObserver source) =>
      _observers.values.where((o) =>
          o != source &&
          o.isReady &&
          o.navigator != null &&
          o.navigator!.mounted);

  void _run(void Function() action) {
    scheduleMicrotask(() {
      _replaying = true;
      try {
        action();
      } finally {
        _replaying = false;
      }
    });
  }

  bool _shouldBroadcast() => !_replaying && isEnabled();

  void _broadcastPush(MirrorNavigatorObserver source, Route<dynamic> route) {
    if (!_shouldBroadcast()) return;
    final targets = _targets(source).toList();
    _run(() {
      for (final target in targets) {
        final copy = cloneRoute(route);
        if (copy != null) {
          target.navigator!.push(copy);
        } else if (route.settings.name != null) {
          _pushNamed(target, route.settings);
        } else {
          onOutOfSync?.call(
              target.slotId, 'cannot replay an unnamed ${route.runtimeType}');
        }
      }
    });
  }

  void _broadcastRemove(MirrorNavigatorObserver source, int index,
      {required bool popped}) {
    if (!_shouldBroadcast()) return;
    final targets = _targets(source).toList();
    _run(() {
      for (final target in targets) {
        if (index >= target.pages.length) continue;
        final route = target.pages[index];
        final nav = target.navigator!;
        if (popped && index == target.pages.length - 1 && route.isCurrent) {
          nav.pop();
        } else {
          nav.removeRoute(route);
        }
      }
    });
  }

  void _broadcastReplace(
      MirrorNavigatorObserver source, int index, Route<dynamic> newRoute) {
    if (!_shouldBroadcast()) return;
    final targets = _targets(source).toList();
    _run(() {
      for (final target in targets) {
        if (index >= target.pages.length) continue;
        final copy = cloneRoute(newRoute);
        if (copy == null) {
          onOutOfSync?.call(target.slotId,
              'cannot replay a replace with ${newRoute.runtimeType}');
          continue;
        }
        target.navigator!
            .replace(oldRoute: target.pages[index], newRoute: copy);
      }
    });
  }

  void _pushNamed(MirrorNavigatorObserver target, RouteSettings settings) {
    try {
      target.navigator!
          .pushNamed(settings.name!, arguments: settings.arguments);
    } catch (error) {
      onOutOfSync?.call(target.slotId, 'pushNamed(${settings.name}) failed');
    }
  }

  /// A device that just appeared catches up with the deepest stack.
  void _onObserverReady(MirrorNavigatorObserver joined) {
    if (!isEnabled()) return;
    MirrorNavigatorObserver? leader;
    for (final o in _targets(joined)) {
      if (leader == null || o.pages.length > leader.pages.length) leader = o;
    }
    var pages = leader?.pages;
    final remembered = _lastKnownPages;
    if ((pages == null || pages.length <= 1) && remembered != null) {
      pages = remembered;
    }
    if (pages == null || pages.length <= joined.pages.length) return;
    final missing = pages.sublist(joined.pages.length);
    _run(() {
      for (final route in missing) {
        final copy = cloneRoute(route);
        if (copy != null) {
          joined.navigator?.push(copy);
        } else if (route.settings.name != null) {
          _pushNamed(joined, route.settings);
        }
      }
    });
  }

  /// Re-creates [route] for another navigator, or returns null when the route
  /// type is unknown.
  static Route<dynamic>? cloneRoute(Route<dynamic> route) {
    if (route is MaterialPageRoute) {
      return MaterialPageRoute<dynamic>(
        builder: route.builder,
        settings: route.settings,
        maintainState: route.maintainState,
        fullscreenDialog: route.fullscreenDialog,
        allowSnapshotting: route.allowSnapshotting,
      );
    }
    if (route is CupertinoPageRoute) {
      return CupertinoPageRoute<dynamic>(
        builder: route.builder,
        settings: route.settings,
        title: route.title,
        maintainState: route.maintainState,
        fullscreenDialog: route.fullscreenDialog,
      );
    }
    if (route is PageRouteBuilder) {
      return PageRouteBuilder<dynamic>(
        pageBuilder: route.pageBuilder,
        transitionsBuilder: route.transitionsBuilder,
        settings: route.settings,
        transitionDuration: route.transitionDuration,
        reverseTransitionDuration: route.reverseTransitionDuration,
        opaque: route.opaque,
        barrierDismissible: route.barrierDismissible,
        barrierColor: route.barrierColor,
        barrierLabel: route.barrierLabel,
        maintainState: route.maintainState,
        fullscreenDialog: route.fullscreenDialog,
      );
    }
    return null;
  }
}

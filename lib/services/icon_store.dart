import 'dart:async';

import 'package:flutter/foundation.dart';

import 'native_apps.dart';

/// App icons, fetched per package and cached for the lifetime of the process.
///
/// The list arrives without icons (docs/07): decoding 200 PNGs up front made
/// the first frame take seconds. A row asks for its own icon when it is built,
/// so only visible rows ever cost a round trip, and a cache hit is free when
/// the user scrolls back.
class IconStore extends ChangeNotifier {
  IconStore({this.maxEntries = 200});

  /// Shared by the tiles; a fresh instance keeps tests independent.
  static final IconStore instance = IconStore();

  /// Icons are ~10 KB each, so 200 of them is about 2 MB of RAM.
  final int maxEntries;

  /// package name -> PNG bytes, or null once we know there is no icon.
  final Map<String, Uint8List?> _cache = {};
  final Set<String> _inFlight = {};
  Timer? _flush;

  /// The bytes for [pkg], or null while it is unknown / has no icon.
  Uint8List? operator [](String pkg) => _cache[pkg];

  bool isPending(String pkg) =>
      _inFlight.contains(pkg) && !_cache.containsKey(pkg);

  /// Ask for [pkg] once. Repeated calls for a settled package do nothing.
  void request(String pkg) {
    if (_cache.containsKey(pkg) || _inFlight.contains(pkg)) return;
    _inFlight.add(pkg);
    NativeApps.getIcon(pkg).then(
      (bytes) {
        _settle(pkg, bytes);
      },
      onError: (Object _) {
        // A package that cannot be read stays null: the tile keeps its
        // fallback and we never retry it into a loop.
        _settle(pkg, null);
      },
    );
  }

  void _settle(String pkg, Uint8List? bytes) {
    _inFlight.remove(pkg);
    _cache[pkg] = bytes;
    // Insertion ordered, so the oldest icon is the first to go.
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _notify();
  }

  /// Coalesce: a page of rows answering at once must not cost one full list
  /// rebuild per icon.
  void _notify() {
    if (_flush?.isActive ?? false) return;
    _flush = Timer(const Duration(milliseconds: 50), notifyListeners);
  }

  /// Forget everything (a package change on the device makes icons stale).
  void clear() {
    _cache.clear();
    _inFlight.clear();
    notifyListeners();
  }

  @visibleForTesting
  void seed(String pkg, Uint8List? bytes) => _settle(pkg, bytes);

  @override
  void dispose() {
    _flush?.cancel();
    super.dispose();
  }
}

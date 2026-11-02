import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/services/icon_store.dart';
import 'package:goodbye_apps/widgets/app_tile.dart';

/// Stands in for the channel so the test measures the widget, not the bridge.
class _FakeStore extends IconStore {
  _FakeStore();

  final List<String> requested = [];
  final Map<String, Uint8List> bytes = {};

  @override
  void request(String pkg) => requested.add(pkg);

  @override
  Uint8List? operator [](String pkg) => bytes[pkg];

  void deliver(String pkg) {
    bytes[pkg] = Uint8List.fromList([1, 2, 3]);
    notifyListeners();
  }
}

void main() {
  Widget host(IconStore store, String pkg) => Builder(
    builder: (context) => MaterialApp(
      home: Scaffold(
        body: LazyAppIcon(
          packageName: pkg,
          scheme: Theme.of(context).colorScheme,
          store: store,
        ),
      ),
    ),
  );

  testWidgets('shows the fallback until the bytes land', (tester) async {
    final store = _FakeStore();
    await tester.pumpWidget(host(store, 'com.example.a'));

    expect(store.requested, ['com.example.a']);
    expect(find.byIcon(Icons.android), findsOneWidget);
    expect(tester.widget<AppIcon>(find.byType(AppIcon)).icon, isNull);

    store.deliver('com.example.a');
    await tester.pump();

    expect(find.byIcon(Icons.android), findsNothing);
    expect(tester.widget<AppIcon>(find.byType(AppIcon)).icon, isNotNull);
  });

  testWidgets('a recycled row asks for the package it now shows', (
    tester,
  ) async {
    final store = _FakeStore();

    await tester.pumpWidget(host(store, 'com.example.a'));
    await tester.pumpWidget(host(store, 'com.example.b'));
    await tester.pumpWidget(host(store, 'com.example.b'));

    expect(store.requested, ['com.example.a', 'com.example.b']);
  });
}

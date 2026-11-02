import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/services/icon_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');

  late List<String> asked;
  late bool unavailable;
  late IconStore store;

  setUp(() {
    asked = [];
    unavailable = false;
    store = IconStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'getIcon') return null;
          final pkg = (call.arguments as Map)['package'] as String;
          asked.add(pkg);
          // What the Kotlin side answers when it cannot draw the icon.
          if (unavailable) throw PlatformException(code: 'no_icon');
          return Uint8List.fromList([pkg.length, pkg.length]);
        });
  });

  tearDown(() {
    store.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a row fetches its icon once and then reads it from the cache',
    () async {
      store.request('com.example.a');
      expect(store.isPending('com.example.a'), isTrue);
      await pumpEventQueue();

      expect(store.isPending('com.example.a'), isFalse);
      expect(
        store['com.example.a'],
        Uint8List.fromList(['com.example.a'.length, 'com.example.a'.length]),
      );

      store.request('com.example.a');
      await pumpEventQueue();
      expect(asked, ['com.example.a'], reason: 'the second row must be free');
    },
  );

  test('a package with no icon is remembered, not retried forever', () async {
    unavailable = true;

    store.request('com.example.b');
    await pumpEventQueue();

    expect(store['com.example.b'], isNull);
    expect(store.isPending('com.example.b'), isFalse);

    store.request('com.example.b');
    await pumpEventQueue();
    expect(asked, ['com.example.b']);
  });

  test(
    'a burst of replies repaints the list once, not once per icon',
    () async {
      var notified = 0;
      store.addListener(() => notified++);

      store.request('com.example.a');
      store.request('com.example.b');
      store.request('com.example.c');
      await pumpEventQueue();
      expect(notified, 0, reason: 'the flush is coalesced, not immediate');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notified, 1);
      expect(store['com.example.a'], isNotNull);
      expect(store['com.example.b'], isNotNull);
      expect(store['com.example.c'], isNotNull);
    },
  );

  test('the cache is bounded and drops the oldest icon first', () async {
    store.dispose();
    store = IconStore(maxEntries: 2);

    for (final pkg in ['a', 'b', 'c']) {
      store.request('com.example.$pkg');
      await pumpEventQueue();
    }

    expect(store['com.example.a'], isNull, reason: 'evicted');
    expect(store['com.example.b'], isNotNull);
    expect(store['com.example.c'], isNotNull);
  });

  test('clear forgets both answers and in-flight requests', () async {
    store.request('com.example.a');
    await pumpEventQueue();
    store.clear();

    expect(store['com.example.a'], isNull);
    store.request('com.example.a');
    await pumpEventQueue();
    expect(asked, ['com.example.a', 'com.example.a']);
  });
}

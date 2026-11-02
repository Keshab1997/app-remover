import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/services/native_apps.dart';

/// What the size cells in the action sheet are only as good as.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('goodbye_apps/native');
  Object? answer;

  setUp(() {
    answer = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getSizeBreakdown':
            case 'hasUsageAccess':
            case 'usageAccessSettings':
              return answer;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sizeBreakdown reads the four keys the Kotlin side sends', () async {
    answer = {'app': 100, 'data': 250, 'cache': 50, 'total': 400};

    final breakdown = await NativeApps.sizeBreakdown('com.example.a');

    expect(breakdown, (app: 100, data: 250, cache: 50, total: 400));
  });

  test('missing keys count as zero rather than throwing', () async {
    answer = {'app': 100};

    expect(await NativeApps.sizeBreakdown('com.example.a'), (
      app: 100,
      data: 0,
      cache: 0,
      total: 0,
    ));
  });

  test(
    'no usage access means no breakdown, so the sheet shows nothing',
    () async {
      answer = null;

      expect(await NativeApps.sizeBreakdown('com.example.a'), isNull);
    },
  );

  test('a float byte count from the bridge is still an int', () async {
    answer = {'app': 12.0, 'data': 0.0, 'cache': 0.0, 'total': 12.0};

    expect(await NativeApps.sizeBreakdown('com.example.a'), (
      app: 12,
      data: 0,
      cache: 0,
      total: 12,
    ));
  });

  test(
    'usage access answers are read as false when the bridge says nothing',
    () async {
      answer = null;

      expect(await NativeApps.hasUsageAccess(), isFalse);
      expect(await NativeApps.openUsageAccessSettings(), isFalse);

      answer = true;
      expect(await NativeApps.hasUsageAccess(), isTrue);
      expect(await NativeApps.openUsageAccessSettings(), isTrue);
    },
  );
}

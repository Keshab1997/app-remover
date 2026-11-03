import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodbye_apps/l10n/generated/app_localizations.dart';
import 'package:goodbye_apps/models/app_info.dart';
import 'package:goodbye_apps/widgets/app_tile.dart';

/// The row is the whole product: one line per app, three facts on it. If it
/// cannot carry a large font, or a screen reader cannot tell which app a box
/// belongs to, the list is unusable for the people who need it most
/// (docs/12 P2-12).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final app = AppInfo(
    packageName: 'com.example.maps',
    label: 'Maps',
    isSystem: false,
    sizeBytes: 148000000,
    firstInstallTime: 1000,
    lastUpdateTime: 1000,
    versionName: '1.0',
    versionCode: 1,
    lastUsedAt: 1000,
  );

  Future<void> pump(WidgetTester tester, {required double scale}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: AppTile(
              app: app,
              selected: false,
              selecting: true,
              onTap: () {},
              onLongPress: () {},
              onSelectedChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a 3x font scale does not break the row', (tester) async {
    await pump(tester, scale: 3.0);

    expect(tester.takeException(), isNull);
    expect(find.text('Maps'), findsOneWidget);
  });

  testWidgets('the selection box is named after its app', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, scale: 1.0);

    final SemanticsNode box = tester.getSemantics(find.byType(Checkbox));
    expect(
      box.label,
      contains('Maps'),
      reason: 'otherwise it is announced as just "Checkbox, unchecked"',
    );

    handle.dispose();
  });
}

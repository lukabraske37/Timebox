import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/ui.dart';

/// Resting on the handle before pulling it used to hand the gesture to the
/// card's own long press, so the block moved instead of growing — and since a
/// second reach for the handle is usually slower than the first, it looked
/// like resizing simply stopped working after one go.
void main() {
  testWidgets('holding the handle before pulling still resizes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    tester.view.padding = const FakeViewPadding(top: 140, bottom: 60);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_timeline).last);
    await tester.pumpAndSettle();

    final store = AppScope.of(tester.element(find.byType(Shell)));

    Finder handle() => find
        .byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('resize-'))
        .first;
    String idOf() =>
        ((tester.widget(handle()).key as ValueKey<String>).value).substring('resize-'.length);

    // Three goes in a row, each one dawdling past the long press threshold.
    for (var pass = 1; pass <= 3; pass++) {
      final id = idOf();
      final before = store.blocks.firstWhere((b) => b.id == id);
      final wasStart = before.start;
      final wasDur = before.duration;

      final g = await tester.startGesture(tester.getRect(handle()).center);
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, 9));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();

      final after = store.blocks.firstWhere((b) => b.id == idOf());
      expect(after.duration, greaterThan(wasDur),
          reason: 'go $pass: pulling the handle should lengthen the block');
      expect(after.start, wasStart,
          reason: 'go $pass: it should not have moved the block instead');
    }
  });
}

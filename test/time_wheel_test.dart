import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/sheets.dart';
import 'package:timebox/store.dart';
import 'package:timebox/theme.dart';
import 'package:timebox/ui.dart';

/// The time wheel used to round every drag event on its own, so movement under
/// half a step was discarded and the result depended on how many events the
/// screen produced. The same drag has to land in the same place whether the
/// phone reports it in fine or coarse steps.
void main() {
  /// Drags the wheel [total] pixels upward, split across [events] moves, and
  /// returns the range shown on the wheel afterwards.
  Future<String> dragWheel(WidgetTester tester,
      {required int events, double total = 140}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);

    final store = Store();
    store.booted = true;
    store.selected = DateTime(2026, 8, 15);

    await tester.pumpWidget(AppScope(
      store: store,
      colors: AppColors.resolve(store.theme, store.accent),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => openBlockSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('New Task'), findsOneWidget, reason: 'the block sheet should open');

    // Every row of the wheel shows a "start – end" range and all of them move
    // together, so the top one is enough to read the wheel's position.
    Finder range() => find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(' – '));

    final before = tester.widget<Text>(range().first).data!;

    final gesture = await tester.startGesture(tester.getCenter(range().at(1)));
    for (var i = 0; i < events; i++) {
      await gesture.moveBy(Offset(0, -total / events));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final after = tester.widget<Text>(range().first).data!;
    expect(after, isNot(before), reason: 'dragging should move the time at all');
    return after;
  }

  testWidgets('the wheel lands in the same place however the drag is reported',
      (tester) async {
    final coarse = await dragWheel(tester, events: 7); // 20px per event
    final fine = await dragWheel(tester, events: 70); // 2px per event

    expect(fine, coarse,
        reason: 'the same 140px drag must give the same time, fine or coarse');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/ui.dart';

/// The handle that changes a block's length used to span the whole width of
/// the card, so a scroll begun anywhere near the foot of a card resized the
/// block instead of moving the day.
void main() {
  Future<void> openTimeline(WidgetTester tester) async {
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
  }

  Future<void> dragFrom(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(at);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 14));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the handle only takes the drag where it is drawn', (tester) async {
    await openTimeline(tester);
    final store = AppScope.of(tester.element(find.byType(Shell)));

    final handle = find
        .byWidgetPredicate((w) => w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('resize-'))
        .first;
    final box = tester.getRect(handle);
    final id = ((tester.widget(handle).key as ValueKey<String>).value).substring('resize-'.length);
    final before = {for (final b in store.blocks) b.id: b.duration};

    // A thumb scrolling the day lands on the card, low down but well away
    // from the handle — which is exactly where the old full-width strip was.
    final card = tester.getRect(find.byKey(ValueKey('card-$id')));
    final beside = Offset(card.left + 24, box.center.dy);
    expect(card.contains(beside), isTrue, reason: 'the grab point is on the card');
    await dragFrom(tester, beside);

    for (final b in store.blocks) {
      expect(b.duration, before[b.id],
          reason: '${b.title} changed length while the day was being scrolled');
    }

    // On the handle itself it must still work.
    await dragFrom(tester, box.center);

    final resized = store.blocks.firstWhere((b) => b.id == id);
    expect(resized.duration, greaterThan(before[id]!),
        reason: 'pulling the handle down should lengthen the block');
  });
}

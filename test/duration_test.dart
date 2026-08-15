import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/sheets.dart';
import 'package:timebox/store.dart';
import 'package:timebox/theme.dart';
import 'package:timebox/ui.dart';

/// The preset chips stop at an hour and a half. "More…" opens wheels that reach
/// twelve hours, and what they pick has to end up on the block.
void main() {
  Future<Store> openBlockEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);

    final store = Store();
    store.booted = true;
    store.selected = DateTime(2026, 8, 16);

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
    return store;
  }

  testWidgets('the wheels set a length the chips cannot reach', (tester) async {
    final store = await openBlockEditor(tester);

    expect(find.byType(DurationPicker), findsNothing,
        reason: 'the wheels stay out of the way until asked for');
    await tester.tap(find.text('More…').last);
    await tester.pumpAndSettle();
    expect(find.byType(DurationPicker), findsOneWidget);

    // Roll the hours wheel up by three notches; the block opens at 30 minutes,
    // so the minutes wheel stays where it is.
    final hours = find.descendant(
      of: find.byType(DurationPicker),
      matching: find.byType(ListWheelScrollView),
    );
    await tester.drag(hours.first, const Offset(0, -120));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Long meeting');
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    final block = store.blocks.firstWhere((b) => b.title == 'Long meeting');
    expect(block.duration, greaterThan(90),
        reason: 'the chips top out at 90 minutes; the wheels must go past it');
    expect(block.duration, 3 * 60 + 30,
        reason: 'three hours on the wheel plus the 30 minutes already set');
    expect(block.end - block.start, block.duration);
  });
}

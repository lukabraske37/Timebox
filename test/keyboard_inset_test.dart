import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/sheets.dart';
import 'package:timebox/store.dart';
import 'package:timebox/theme.dart';
import 'package:timebox/ui.dart';

/// Editor sheets autofocus their title field, so the keyboard arrives a moment
/// after they open. The sheet has to give way to it — build 18 read the inset
/// from the caller's context, froze it at zero and let the keyboard cover the
/// field being typed into.
void main() {
  const screen = 914.0;
  const keyboard = 340.0;

  Future<void> openSheet(WidgetTester tester) async {
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
                onPressed: () => openInboxSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
  }

  testWidgets('the sheet gives way to the keyboard', (tester) async {
    await openSheet(tester);

    final beforeField = tester.getRect(find.byType(TextField));
    expect(beforeField.bottom, lessThan(screen), reason: 'sanity: field is on screen');

    // The keyboard comes up.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3.5);
    await tester.pumpAndSettle();

    final top = screen - keyboard;
    final field = tester.getRect(find.byType(TextField));
    final save = tester.getRect(find.byType(PrimaryButton));

    expect(field.bottom, lessThanOrEqualTo(top),
        reason: 'the field being typed into must stay above the keyboard');
    expect(save.bottom, lessThanOrEqualTo(top),
        reason: 'the save button must stay above the keyboard');
    expect(field.top, greaterThanOrEqualTo(0),
        reason: 'the sheet must not be pushed off the top of the screen');
  });
}

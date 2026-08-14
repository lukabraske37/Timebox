import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/sheets.dart';

/// Editor sheets run to the bottom edge of the screen, so their footer has to
/// keep the destructive action clear of the system navigation bar. Build 14 cut
/// "Delete" in half behind the back and home buttons.
void main() {
  testWidgets('the delete button clears the system navigation bar', (tester) async {
    const navBar = 48.0;

    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    tester.view.padding = const FakeViewPadding(top: 140, bottom: navBar * 3.5);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    final button = find.byType(DeleteButton);
    expect(button, findsOneWidget, reason: 'the inbox editor should offer Delete');

    final rect = tester.getRect(button);
    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    expect(rect.bottom, lessThanOrEqualTo(screen - navBar),
        reason: 'Delete must sit above the navigation bar, not under it');
    expect(rect.height, greaterThanOrEqualTo(48),
        reason: 'Delete needs a tap target worth aiming at');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';

/// Selecting a block opens the timeline action bar in the bottom corner the
/// floating button already occupies. Build 15 drew the button straight over the
/// action bar's Edit row.
void main() {
  testWidgets('the add button gets out of the way of a selected block',
      (tester) async {
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
    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: 'the timeline offers a new block while nothing is selected');

    await tester.tap(find.text('Morning run'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget, reason: 'the action bar should open');
    expect(find.byType(FloatingActionButton), findsNothing,
        reason: 'the add button must not sit on top of the action bar');
  });
}

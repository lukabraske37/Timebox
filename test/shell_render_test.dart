import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';

/// The navigation bar is handed loose constraints by the Scaffold, so anything
/// greedy inside it eats the whole screen and collapses the body — which is
/// exactly what shipped in build 11. These tests pin the shell's geometry down
/// on every tab.
void main() {
  Future<void> startApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    tester.view.padding = const FakeViewPadding(top: 140, bottom: 60);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
  }

  ({Size body, Size nav}) slots(WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(find.byType(CustomMultiChildLayout).first);
    var body = Size.zero;
    var nav = Size.zero;
    box.visitChildren((child) {
      final b = child as RenderBox;
      final id = (b.parentData as MultiChildLayoutParentData).id.toString();
      if (id.endsWith('body')) body = b.size;
      if (id.endsWith('bottomNavigationBar')) nav = b.size;
    });
    return (body: body, nav: nav);
  }

  testWidgets('every tab keeps the body tall and the nav bar short', (tester) async {
    await startApp(tester);
    const tabs = ['Inbox', 'Timeline', 'Tasks', 'Habits', 'Settings'];
    const icons = [
      Icons.inbox,
      Icons.view_timeline,
      Icons.checklist,
      Icons.local_fire_department,
      Icons.settings,
    ];

    for (var i = 0; i < tabs.length; i++) {
      await tester.tap(find.byIcon(icons[i]).last);
      await tester.pumpAndSettle();

      final s = slots(tester);
      expect(s.nav.height, lessThan(120),
          reason: '${tabs[i]}: nav bar must not grow past its own content');
      expect(s.body.height, greaterThan(600),
          reason: '${tabs[i]}: body should get the rest of the screen');
      expect(tester.takeException(), isNull, reason: '${tabs[i]}: threw while building');
    }
  });
}

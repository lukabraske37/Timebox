import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';
import 'package:timebox/ui.dart';

/// Tasks used to carry only a time of day, so "pay the bill at 6pm" could not
/// say *which* 6pm. A task now takes a due date, and the list is ordered by it.
void main() {
  Future<Store> openTasks(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    tester.view.padding = const FakeViewPadding(top: 140, bottom: 60);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.checklist).last);
    await tester.pumpAndSettle();
    return AppScope.of(tester.element(find.byType(Scaffold).first));
  }

  testWidgets('a task can be given a day, not just a time', (tester) async {
    final store = await openTasks(tester);
    final task = store.tasks.firstWhere((t) => !t.done && t.date == null);

    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();

    expect(find.text('When is it due?'), findsOneWidget,
        reason: 'the task editor should offer a due date');

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final tomorrow = dateKey(DateTime.now().add(const Duration(days: 1)));
    expect(store.tasks.firstWhere((t) => t.id == task.id).date, tomorrow,
        reason: 'the chosen day should be saved on the task');
    expect(find.text('Tomorrow'), findsWidgets,
        reason: 'and the list should show which day it is due');
  });

  test('a due date is written out with the rest of the task', () {
    final saved = Task(id: 'x', title: 'Call the dentist', time: 600, date: '2026-12-24').toJson();
    expect(saved['date'], '2026-12-24',
        reason: 'the due date has to reach disk, or it is gone on next launch');
    expect(Task.fromJson(saved).date, '2026-12-24', reason: 'and come back on load');
    expect(Task.fromJson({'id': 'y', 'title': 'Old task', 'done': false}).date, isNull,
        reason: 'tasks saved before due dates existed must still load');
  });

  testWidgets('what is due soonest is listed first', (tester) async {
    final store = await openTasks(tester);
    final today = todayKey();
    final later = dateKey(DateTime.now().add(const Duration(days: 4)));
    store.mutate(() {
      store.tasks
        ..clear()
        ..addAll([
          Task(id: 'a', title: 'Someday job'),
          Task(id: 'b', title: 'Later job', date: later),
          Task(id: 'c', title: 'Finished job', date: today, done: true),
          Task(id: 'd', title: 'Today job', date: today),
        ]);
    });
    await tester.pumpAndSettle();

    double topOf(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(topOf('Today job'), lessThan(topOf('Later job')),
        reason: 'the nearer due date comes first');
    expect(topOf('Later job'), lessThan(topOf('Someday job')),
        reason: 'a dated task outranks one with no date at all');
    expect(topOf('Someday job'), lessThan(topOf('Finished job')),
        reason: 'and anything finished still sinks to the bottom');
  });
}

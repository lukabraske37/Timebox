import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';
import 'package:timebox/ui.dart';

/// A reminder can ring as an alarm instead of arriving as a notification.
void main() {
  testWidgets('a task reminder can be switched to an alarm', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.checklist).last);
    await tester.pumpAndSettle();
    final store = AppScope.of(tester.element(find.byType(Scaffold).first));

    final task = store.tasks.firstWhere((t) => t.time != null && !t.done);
    expect(task.alarm, isFalse);
    await tester.tap(find.text(task.title));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(store.tasks.firstWhere((t) => t.id == task.id).alarm, isTrue);
    expect(find.byIcon(Icons.alarm), findsWidgets, reason: 'the list should show it rings');
  });

  test('the alarm choice is saved, and old data loads without one', () {
    final t = Task.fromJson(Task(id: 'a', title: 'Wake', time: 420, alarm: true).toJson());
    expect(t.alarm, isTrue);
    expect(Task.fromJson({'id': 'b', 'title': 'Old'}).alarm, isFalse);

    final b = Block(id: 'b', date: todayKey(), icon: 'label', title: 'Gym', start: 600, end: 660, alarm: true);
    expect(Block.fromJson(b.toJson()).alarm, isTrue);
    expect(b.occurrenceOn('2026-12-01').alarm, isTrue, reason: 'a repeat rings like the original');

    expect(Habit.fromJson(Habit(id: 'h', title: 'Read', time: 1300, alarm: true).toJson()).alarm, isTrue);
  });

  test('snooze rings again in ten minutes, once per alarm', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store(notifications: false);
    await store.load();
    addTearDown(store.dispose);

    store.snooze('Wake up');
    store.snooze('Wake up');
    expect(store.snoozes.length, 1, reason: 'pressing Snooze twice is still one alarm');
    final wait = store.snoozes.single.at.difference(DateTime.now()).inSeconds;
    expect(wait, inInclusiveRange(kSnoozeMinutes * 60 - 5, kSnoozeMinutes * 60));

    store.flush();
    final again = Store(notifications: false);
    addTearDown(again.dispose);
    await again.load();
    expect(again.snoozes.single.title, 'Wake up', reason: 'a snooze has to survive the app closing');
  });
}

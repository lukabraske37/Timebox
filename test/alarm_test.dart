import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/main.dart';
import 'package:timebox/models.dart';
import 'package:timebox/services.dart';
import 'package:timebox/sheets.dart';
import 'package:timebox/store.dart';
import 'package:timebox/theme.dart';
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

    
    expect(Habit.fromJson(Habit(id: 'h', title: 'Read', time: 1300, alarm: true).toJson()).alarm, isTrue);
  });

  test('snooze rings again in ten minutes, once per alarm', () {
    final now = DateTime(2026, 11, 15, 7, 0);
    var raw = Notifications.withSnooze(null, 'Wake up', now);
    raw = Notifications.withSnooze(raw, 'Wake up', now);
    raw = Notifications.withSnooze(raw, 'Take pills', now);

    final pending = Notifications.pendingSnoozes(raw, now);
    expect(pending.map((e) => e['title']), ['Wake up', 'Take pills'],
        reason: 'pressing Snooze twice is still one alarm');
    expect(pending.map((e) => e['id']).toSet().length, 2, reason: 'each needs its own slot');
    expect(DateTime.parse(pending.first['at'] as String), now.add(const Duration(minutes: kSnoozeMinutes)));

    expect(Notifications.pendingSnoozes(raw, now.add(const Duration(minutes: 11))), isEmpty,
        reason: 'one that has rung is done');
    expect(Notifications.pendingSnoozes('not json', now), isEmpty);
  });

  test('an alert can sit any number of minutes before the start', () {
    expect(alertLabel(0), kAtStart);
    expect(alertLabel(7), '7m before start');
    expect(alertLabel(60), '1h before start');
    expect(alertLabel(95), '1h 35m before start');
    for (final m in [1, 7, 15, 30, 60, 95, 240]) {
      expect(alertBefore(alertLabel(m)), m, reason: 'what is written must read back the same');
    }
    // The presets every earlier build wrote.
    expect(alertBefore('15m before start'), 15);
    expect(alertBefore('1h before start'), 60);
    expect(alertBefore(kAtStart), 0);
    expect(alertBefore(kAtEnd), isNull);

    expect(alertTime('7m before start', 540, 60), 533);
    expect(alertTime(kAtEnd, 540, 60), 600);
    expect(alertTime('1h before start', 30, 60), -30, reason: 'before midnight, on the day before');
  });

  test('each alert on a block chooses for itself whether it rings', () {
    final b = Block(
      id: 'b', date: todayKey(), icon: 'label', title: 'Flight', start: 600, end: 660,
      alerts: ['1h before start', kAtStart], rings: [kAtStart],
    );
    final back = Block.fromJson(b.toJson());
    expect(back.rings, [kAtStart]);
    expect(back.occurrenceOn('2026-12-01').rings, [kAtStart], reason: 'a repeat rings like the original');

    // Build 32 stored one switch for the whole block.
    final old = Block.fromJson({
      'id': 'o', 'date': todayKey(), 'start': 600, 'end': 660, 'alerts': ['15m before start'], 'alarm': true,
    });
    expect(old.rings, ['15m before start']);
  });

  testWidgets('the reminder time can be set to the exact minute', (tester) async {
    var minutes = 420;
    await tester.pumpWidget(MaterialApp(
      home: AppScope(
        store: Store(notifications: false),
        colors: AppColors.resolve('dark', 'teal'),
        child: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TimeStepper(minutes: minutes, use24: true, onChanged: (v) => setState(() => minutes = v)),
          ),
        ),
      ),
    ));
    // The second up arrow belongs to the minutes.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up).at(1));
    await tester.pump();
    expect(minutes, 422, reason: 'it used to jump straight to 7:05');
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(1));
    await tester.pump();
    expect(minutes, 421);
  });

  testWidgets('the alert editor sets the minute and the kind', (tester) async {
    ({String label, bool ring})? result;
    // As in the app, the scope sits above the navigator so a dialog can see it.
    await tester.pumpWidget(AppScope(
      store: Store(notifications: false),
      colors: AppColors.resolve('dark', 'teal'),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showDialog(
                context: context,
                builder: (_) => const AlertEditor(label: kAtStart, ring: false, start: 540, duration: 60),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1'));
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();
    expect(find.text('8:43 AM'), findsOneWidget, reason: 'it shows the moment it will fire: 17 minutes before 9:00');

    await tester.tap(find.text('Alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result?.label, '17m before start');
    expect(result?.ring, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';

/// Twice a year a day is not 24 hours long. Counting days by adding or
/// subtracting 24 hours then lands on the wrong date — or on the same date
/// twice. These only bite in a time zone that changes its clocks, so the suite
/// is run with TZ=Europe/Belgrade; under UTC they pass trivially.
void main() {
  tearDown(() => clock = DateTime.now);

  test('a streak counts each day once on the night the clocks go back', () {
    // 25 October 2026 is 25 hours long in Belgrade. At 23:04 the next evening,
    // stepping back 24 hours twice lands on the 25th both times.
    clock = () => DateTime(2026, 10, 26, 23, 4);
    final habit = Habit(id: 'h', title: 'Read', history: {
      for (var d = 20; d <= 26; d++) '2026-10-$d': true,
    });
    expect(habit.streak, 7, reason: 'seven days ticked is a streak of seven, not eight');
    expect(habit.streak, lessThanOrEqualTo(habit.history.length),
        reason: 'a streak can never be longer than the number of days ticked');
  });

  test('a weekly block still comes round after the clocks go forward', () {
    final store = Store(notifications: false);
    addTearDown(store.dispose);
    store.blocks = [
      Block(id: 'w', date: '2026-03-23', icon: 'label', title: 'Gym', start: 600, end: 660, repeat: 'Weekly'),
    ];
    // 29 March 2026 is 23 hours long, so the 30th is 167 hours after the 23rd.
    expect(store.blocksOn('2026-03-30').map((b) => b.title), ['Gym']);
    expect(store.blocksOn('2026-06-01').map((b) => b.title), ['Gym'], reason: 'and all summer');
    expect(store.blocksOn('2026-03-31'), isEmpty);
  });

  test('the day after tomorrow is not called tomorrow across a clock change', () {
    clock = () => DateTime(2026, 3, 28, 12);
    expect(daysUntil('2026-03-29'), 1);
    expect(daysUntil('2026-03-30'), 2);
    expect(dueLabel('2026-03-30'), isNot('Tomorrow'));
    clock = () => DateTime(2026, 3, 30, 12);
    expect(daysUntil('2026-03-28'), -2);
  });

  test('the week strip starts on Monday on either side of a clock change', () {
    final store = Store(notifications: false);
    addTearDown(store.dispose);

    clock = () => DateTime(2026, 3, 30, 10); // the Monday after the spring change
    store.weekOffset = -1;
    expect(store.weekDays.map(dateKey).toList(), [
      for (var d = 23; d <= 29; d++) '2026-03-$d',
    ]);

    clock = () => DateTime(2026, 10, 20, 10); // the Tuesday before the autumn change
    store.weekOffset = 1;
    expect(store.weekDays.first.weekday, DateTime.monday);
    expect(dateKey(store.weekDays.first), '2026-10-26');
    expect(dateKey(store.weekDays.last), '2026-11-01');
  });

  test('stepping a date by whole days never repeats or skips one', () {
    var d = DateTime(2026, 10, 20, 23, 30);
    final seen = <String>{};
    for (var i = 0; i < 14; i++) {
      expect(seen.add(dateKey(addDays(d, i))), isTrue, reason: 'day $i repeated');
    }
    expect(dateKey(addDays(DateTime(2026, 3, 30), -7)), '2026-03-23');
    expect(daysBetween(DateTime(2026, 3, 23), DateTime(2026, 3, 30)), 7);
    expect(daysBetween(DateTime(2026, 10, 26, 23), DateTime(2026, 10, 24, 1)), -2);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';

/// Days used to be a lie: every launch dragged the whole plan forward by the
/// number of days that had passed, so whatever you had planned always landed on
/// today and yesterday's plan was overwritten. What carries forward now is a
/// repeat, which is what "How often?" has been collecting all along.
void main() {
  String key(DateTime d) => dateKey(d);
  final today = DateTime.now();
  DateTime day(int offset) => today.add(Duration(days: offset));

  Store storeWith(List<Block> blocks) {
    final s = Store();
    s.blocks = blocks;
    return s;
  }

  Block block({
    required String id,
    required DateTime on,
    String repeat = 'Once',
    String title = 'Block',
  }) =>
      Block(id: id, date: key(on), icon: 'label', title: title, start: 540, end: 600, repeat: repeat);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a one-off stays on the day it was planned for', () {
    final s = storeWith([block(id: 'a', on: day(-3), title: 'Dentist')]);

    expect(s.blocksOn(key(day(-3))).map((b) => b.title), ['Dentist']);
    expect(s.blocksOn(key(today)), isEmpty, reason: 'it belongs to that day, not to today');
    expect(s.blocksOn(key(day(2))), isEmpty);
  });

  test('a daily block shows up on every later day', () {
    final s = storeWith([block(id: 'a', on: day(-2), repeat: 'Daily', title: 'Morning run')]);

    for (final offset in [-2, -1, 0, 1, 7]) {
      expect(s.blocksOn(key(day(offset))).map((b) => b.title), ['Morning run'],
          reason: 'day $offset should carry the daily block');
    }
    expect(s.blocksOn(key(day(-3))), isEmpty, reason: 'nothing before it started');
  });

  test('a weekly block only lands on the same weekday', () {
    final s = storeWith([block(id: 'a', on: day(-7), repeat: 'Weekly', title: 'Gym')]);

    expect(s.blocksOn(key(today)).map((b) => b.title), ['Gym']);
    expect(s.blocksOn(key(day(7))).map((b) => b.title), ['Gym']);
    expect(s.blocksOn(key(day(1))), isEmpty);
  });

  test('dropping one occurrence leaves the rest of the series alone', () {
    final s = storeWith([block(id: 'a', on: day(-1), repeat: 'Daily', title: 'Standup')]);

    final tomorrow = s.blocksOn(key(day(1))).single;
    s.deleteBlock(tomorrow.id);

    expect(s.blocksOn(key(day(1))), isEmpty, reason: 'that one day is off');
    expect(s.blocksOn(key(today)).map((b) => b.title), ['Standup'], reason: 'today still stands');
    expect(s.blocksOn(key(day(2))).map((b) => b.title), ['Standup'], reason: 'so does the day after');
  });

  test('checking the clock on the same day leaves your browsing alone', () {
    final s = storeWith([]);
    s.selected = day(4);
    s.weekOffset = 1;

    s.syncToToday();

    expect(s.selectedKey, key(day(4)),
        reason: 'the date has not changed, so the day being looked at should not either');
    expect(s.weekOffset, 1);
  });

  test('moving one occurrence does not move the whole series', () {
    final s = storeWith([block(id: 'a', on: day(-1), repeat: 'Daily', title: 'Standup')]);

    final tomorrow = s.blocksOn(key(day(1))).single;
    s.moveBlock(tomorrow.id, 60);

    expect(s.blocksOn(key(day(1))).single.start, 600, reason: 'the day we touched moved');
    expect(s.blocksOn(key(today)).single.start, 540, reason: 'today did not');
    expect(s.blocksOn(key(day(2))).single.start, 540, reason: 'nor did the day after');
  });
}

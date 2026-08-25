import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';

/// A new block should land after whatever is already planned, so one follows
/// another instead of dropping the user at a fixed hour to scroll away from.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Store storeOn(DateTime day, List<Block> blocks) {
    final s = Store();
    s.selected = day;
    s.blocks = blocks;
    return s;
  }

  Block block(String id, DateTime on, int start, int end) =>
      Block(id: id, date: dateKey(on), icon: 'label', title: id, start: start, end: end);

  test('an empty day opens at nine', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(storeOn(tomorrow, []).nextFreeStart(), 540);
  });

  test('a new block follows straight on from the last one', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    // 6:30 to 6:31, the way you would block out waking up.
    final s = storeOn(tomorrow, [block('sleep', tomorrow, 390, 391)]);

    expect(s.nextFreeStart(), 391, reason: 'the next block should carry on at 6:31');
  });

  test('the last end wins even when a later block is shorter', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = storeOn(tomorrow, [
      block('long', tomorrow, 540, 780),
      block('short', tomorrow, 600, 615),
    ]);

    expect(s.nextFreeStart(), 780);
  });

  test('today never suggests a time that has already gone', () {
    final s = storeOn(DateTime.now(), []);
    s.now = 900; // 3:00 PM

    expect(s.nextFreeStart(), greaterThanOrEqualTo(900),
        reason: '9:00 has passed by then, so it should not be offered');
  });

  zoomTests();

  test('the day summary counts what is planned and what is free', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = storeOn(tomorrow, [
      block('a', tomorrow, 540, 600), // 1h
      block('b', tomorrow, 660, 720), // 1h, an hour later
    ]);

    final summary = s.daySummary();
    expect(summary.count, 2);
    expect(summary.planned, 120);
    expect(summary.free, 60, reason: 'the hour between the two');
  });
}

/// "Hours on screen" could not do its job while every block was forced to the
/// same minimum height: a 45 minute block came out 76px tall at both the
/// tightest and the loosest zoom, so the setting changed nothing you could see.
void zoomTests() {
  test('the zoom setting changes how much of the day fits on screen', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = Store()..selected = tomorrow;
    s.blocks = [
      Block(id: 'a', date: dateKey(tomorrow), icon: 'label', title: 'a', start: 540, end: 585),
      Block(id: 'b', date: dateKey(tomorrow), icon: 'label', title: 'b', start: 780, end: 825),
    ];

    s.zoom = 'compact';
    final tight = s.layout().trackHeight;
    s.zoom = 'roomy';
    final loose = s.layout().trackHeight;

    expect(loose, greaterThan(tight * 2),
        reason: 'the loosest zoom should show far less of the day at once');
  });
}

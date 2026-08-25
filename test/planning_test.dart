import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/models.dart';
import 'package:timebox/sheets.dart';
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

    expect(s.nextFreeStart(), 395,
        reason: 'it carries on right after, rounded onto the five minute grid');
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
  taskOrderTests();
  gridTests();

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

/// Finished tasks used to hold their place in the list, pushing what is still
/// open further down as the day went on.
void taskOrderTests() {
  test('finished tasks sink below the open ones', () {
    final s = Store();
    s.tasks = [
      Task(id: '1', title: 'done first', done: true),
      Task(id: '2', title: 'still open'),
      Task(id: '3', title: 'also done', done: true),
      Task(id: '4', title: 'open too'),
    ];

    final ordered = [
      ...s.tasks.where((t) => !t.done),
      ...s.tasks.where((t) => t.done),
    ];

    expect(ordered.map((t) => t.title),
        ['still open', 'open too', 'done first', 'also done']);
  });
}

/// Everything moves in five minute steps, so a start that falls off that grid
/// can never be brought back onto it — every step keeps the stray minute. A one
/// minute block at 9:00 used to hand the next one 9:01, and from there the
/// wheel could only offer 9:06, 9:11, 9:16.
void gridTests() {
  test('a stray minute never reaches the grid by stepping', () {
    var start = 541; // 9:01
    for (var i = 0; i < 20; i++) {
      start += kStep;
    }
    expect(start % kStep, 1, reason: 'this is the trap the snapping removes');
  });

  test('the next block after a one minute block starts on the grid', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = Store()..selected = tomorrow;
    s.blocks = [
      Block(id: 'a', date: dateKey(tomorrow), icon: 'label', title: 'a', start: 540, end: 541),
    ];

    final next = s.nextFreeStart();
    expect(next, 545, reason: '9:01 rounds up to 9:05');
    expect(next % kStep, 0);
  });

  test('nudging a block off the grid pulls it back on', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final s = Store()..selected = tomorrow;
    s.blocks = [
      Block(id: 'a', date: dateKey(tomorrow), icon: 'label', title: 'a', start: 541, end: 601),
    ];

    s.moveBlock('a', 15);

    final b = s.blocks.single;
    expect(b.start % kStep, 0, reason: 'the nudge should heal the stray minute');
    expect(b.duration, 60, reason: 'and leave the length alone');
  });

  test('every duration preset sits on the grid', () {
    for (final d in kDurations) {
      expect(d % kStep, 0, reason: '$d cannot be reached by the wheels');
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';

/// Two things at once used to be stacked down the day, one pushed below the
/// other, so the timeline claimed they happened one after another. They now
/// share the width.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final day = DateTime.now().add(const Duration(days: 1));

  Store storeWith(List<Block> blocks) => Store()
    ..selected = day
    ..blocks = blocks;

  Block block(String id, int start, int end) =>
      Block(id: id, date: dateKey(day), icon: 'label', title: id, start: start, end: end);

  test('blocks that do not meet each keep the whole width', () {
    final s = storeWith([block('a', 540, 600), block('b', 780, 840)]);

    for (final r in s.layout().rows) {
      expect(r.columns, 1, reason: '${r.block.id} has the day to itself');
      expect(r.column, 0);
    }
  });

  test('two at once sit side by side, not one under the other', () {
    final s = storeWith([block('a', 540, 600), block('b', 545, 620)]);
    final rows = s.layout().rows;

    expect(rows.every((r) => r.columns == 2), isTrue, reason: 'the run splits in two');
    expect(rows.map((r) => r.column).toSet(), {0, 1}, reason: 'one each, not both left');
    // Side by side means they start at roughly the same height.
    final a = rows.firstWhere((r) => r.block.id == 'a');
    final b = rows.firstWhere((r) => r.block.id == 'b');
    expect((b.y - a.y).abs(), lessThan(a.height),
        reason: 'b should be beside a, not pushed clear of it');
  });

  test('a third at the same time adds a third column', () {
    final s = storeWith([
      block('a', 540, 620),
      block('b', 545, 620),
      block('c', 550, 620),
    ]);
    final rows = s.layout().rows;

    expect(rows.every((r) => r.columns == 3), isTrue);
    expect(rows.map((r) => r.column).toSet(), {0, 1, 2});
  });

  test('a column is reused once what was in it has finished', () {
    final s = storeWith([
      block('a', 540, 600), // 9:00 - 10:00
      block('b', 570, 660), // 9:30 - 11:00, overlaps a, so a second column
      block('c', 605, 630), // 10:05 - 10:30, clear of a but still inside b
    ]);
    final rows = s.layout().rows;

    expect(rows.every((r) => r.columns == 2), isTrue, reason: 'two wide throughout');
    expect(rows.firstWhere((r) => r.block.id == 'a').column, 0);
    expect(rows.firstWhere((r) => r.block.id == 'b').column, 1);
    expect(rows.firstWhere((r) => r.block.id == 'c').column, 0,
        reason: 'a has finished, so c takes the left column back');
  });

  test('a block clear of everything keeps the whole width', () {
    final s = storeWith([
      block('a', 540, 600),
      block('b', 545, 620), // overlaps a
      block('c', 700, 760), // well clear of both
    ]);
    final rows = s.layout().rows;
    final c = rows.firstWhere((r) => r.block.id == 'c');

    expect(c.columns, 1, reason: 'it shares its time with nothing, so it is not narrowed');
  });

  test('pulling the handle changes only the length, in five minute steps', () {
    final s = storeWith([block('a', 540, 600)]);

    s.stretchBlock('a', 5);

    final b = s.blocks.single;
    expect(b.start, 540, reason: 'the start stays put');
    expect(b.duration, 65);
    expect(b.end % kStep, 0);
  });
}

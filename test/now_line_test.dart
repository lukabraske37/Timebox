import 'package:flutter_test/flutter_test.dart';
import 'package:timebox/models.dart';
import 'package:timebox/store.dart';

/// The line for the current time has to sit where the time is drawn, not
/// where it would be if every block were to scale. A five minute block is
/// stretched to stay readable and pushes the rest of the day down with it.
void main() {
  tearDown(() => clock = DateTime.now);

  Store day(List<List<int>> spans) {
    clock = () => DateTime(2026, 11, 16, 15, 16);
    final s = Store(notifications: false);
    s.blocks = [
      for (var i = 0; i < spans.length; i++)
        Block(id: '$i', date: '2026-11-16', icon: 'label', title: '$i', start: spans[i][0], end: spans[i][1]),
    ];
    s.selected = clock();
    return s;
  }

  test('the line is inside the block that is running', () {
    // The day from the phone: school, five minutes home, then lunch.
    final s = day([[470, 530], [530, 575], [555, 560], [575, 890], [890, 895], [895, 925]]);
    addTearDown(s.dispose);
    final layout = s.layout();
    final lunch = layout.rows.firstWhere((r) => r.block.start == 895);
    final y = layout.yOf(15 * 60 + 16);
    expect(y, greaterThan(lunch.y), reason: '3:16 is in the 2:55 to 3:25 block, not back in school');
    expect(y, lessThan(lunch.y + lunch.height));
    expect((y - lunch.y) / lunch.height, closeTo(21 / 30, 0.01), reason: 'and 21 minutes of 30 through it');
  });

  test('between two blocks it is that far through the gap', () {
    final s = day([[540, 545], [600, 660]]);
    addTearDown(s.dispose);
    final layout = s.layout();
    final first = layout.rows[0], second = layout.rows[1];
    final bottom = first.y + first.height;
    expect(layout.yOf(545), closeTo(bottom, 0.01));
    expect(layout.yOf(600), closeTo(second.y, 0.01));
    expect(layout.yOf(572), greaterThan(bottom));
    expect(layout.yOf(572), lessThan(second.y));
  });

  test('time never runs backwards down the track', () {
    final s = day([[470, 530], [530, 575], [555, 560], [575, 890], [890, 895], [895, 925]]);
    addTearDown(s.dispose);
    final layout = s.layout();
    var last = double.negativeInfinity;
    for (var m = 440; m <= 960; m++) {
      final y = layout.yOf(m);
      expect(y, greaterThanOrEqualTo(last - 0.01), reason: 'minute $m');
      last = y;
    }
  });
}

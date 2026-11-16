import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../models.dart';
import '../sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final today = todayKey();
    final total = store.habits.length;
    final done = store.habits.where((h) => h.doneOn(today)).length;

    return Column(children: [
      ScreenTitle(
        title: 'Habits',
        subtitle: total == 0
            ? 'Nothing to keep up yet'
            : done == total
                ? 'All $total done today'
                : '$done of $total done today',
        trailing: total == 0 ? null : ProgressRing(value: done / total, label: '$done/$total'),
      ),
      Expanded(
        child: total == 0
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.local_fire_department,
                  title: 'Build a streak',
                  body: 'Add a habit and tick it off each day.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                itemCount: total,
                separatorBuilder: (_, __) => const SizedBox(height: 11),
                itemBuilder: (context, i) => _HabitCard(habit: store.habits[i]),
              ),
      ),
    ]);
  }
}

/// One habit in the list: what it is, how the run stands, the last week at a
/// glance, and the tick for today.
class _HabitCard extends StatelessWidget {
  final Habit habit;
  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final h = habit;
    final tone = toneOf(context, h.color);
    final today = todayKey();
    final isDone = h.doneOn(today);
    final streak = h.streak;

    return Panel(
      key: ValueKey('habit-${h.id}'),
      color: isDone ? washOf(c, tone) : c.surf,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetail(habitId: h.id))),
      child: Row(children: [
        IconTile(icon: iconFor(h.icon), tone: tone),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.txt)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.local_fire_department, size: 15, color: streak > 0 ? tone : c.txt3),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  [
                    streak == 0 ? 'No streak yet' : '$streak day streak',
                    if (h.time != null) fmtMins(h.time!, store.use24),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.txt2),
                ),
              ),
              if (h.time != null) ...[
                const SizedBox(width: 4),
                Icon(h.alarm ? Icons.alarm : Icons.notifications, size: 13, color: c.txt3),
              ],
            ]),
            const SizedBox(height: 10),
            _WeekDots(habit: h, tone: tone),
          ]),
        ),
        CheckCircle(
          done: isDone,
          color: tone,
          size: 44,
          label: isDone ? '${h.title}, done today' : '${h.title}, not done today',
          onTap: () {
            HapticFeedback.selectionClick();
            store.toggleHabit(h.id, today);
          },
        ),
      ]),
    );
  }
}

/// The seven days ending today, oldest first, so the dot on the right is
/// always today.
class _WeekDots extends StatelessWidget {
  final Habit habit;
  final Color tone;
  const _WeekDots({required this.habit, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final now = clock();
    return Row(children: [
      for (var back = 6; back >= 0; back--) ...[
        () {
          final day = addDays(now, -back);
          final hit = habit.doneOn(dateKey(day));
          final isToday = back == 0;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Column(children: [
              Text(_weekdayInitials[day.weekday - 1],
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? c.txt2 : c.txt3)),
              const SizedBox(height: 4),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: hit ? tone : (isToday ? Colors.transparent : c.node),
                  shape: BoxShape.circle,
                  border: isToday && !hit ? Border.all(color: tone, width: 2) : null,
                ),
              ),
            ]),
          );
        }(),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- one habit

class HabitDetail extends StatelessWidget {
  final String habitId;
  const HabitDetail({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final base = AppScope.colorsOf(context);
    final h = store.habits.firstWhereOrNull((x) => x.id == habitId);
    // Deleting pops the page, but it is rebuilt once on the way out.
    if (h == null) return Scaffold(backgroundColor: base.bg);

    // The page takes the habit's colour for everything an accent would touch.
    final tone = store.blockColorIcons ? base.item(h.color) : base.acc;
    return AppScope(
      store: store,
      colors: base.withAccent(tone),
      child: _HabitPage(habit: h),
    );
  }
}

class _HabitPage extends StatefulWidget {
  final Habit habit;
  const _HabitPage({required this.habit});

  @override
  State<_HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends State<_HabitPage> {
  /// How many months back the calendar is turned; zero is this month.
  int _monthsBack = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final h = widget.habit;
    final range = kRanges.firstWhere((r) => r.key == store.habitRange, orElse: () => kRanges.first);
    final today = todayKey();
    final isDone = h.doneOn(today);
    final streak = h.streak;

    // A habit begun last month has not "missed" the five months before it,
    // so the rate is taken over the days it has existed, up to the range.
    final ticked = h.history.keys.where(h.doneOn);
    final first = ticked.isEmpty ? null : ticked.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final age = first == null ? 0 : daysBetween(keyToDate(first), clock()) + 1;
    final window = range.allTime || age < range.days ? age : range.days;
    final hits = h.hitsIn(window);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: c.txt),
              ),
              Expanded(
                child: Text(h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.txt)),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => openHabitSheet(context, existing: h),
                icon: Icon(Icons.edit, size: 21, color: c.txt2),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: 'Delete this habit?',
                    body: '"${h.title}" and its ${h.total} ticked ${h.total == 1 ? 'day' : 'days'} are removed.',
                    action: 'Delete',
                    danger: true,
                  );
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  store.deleteHabit(h.id);
                },
                icon: Icon(Icons.delete_outline, size: 22, color: c.danger),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                _hero(context, store, c, h, streak, isDone),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _stat(c, 'BEST', '${h.bestStreak}', h.bestStreak == 1 ? 'day in a row' : 'days in a row'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(c, 'TOTAL', '${h.total}', h.total == 1 ? 'day ticked' : 'days ticked')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(
                      c,
                      'RATE',
                      window == 0 ? '–' : '${(hits / window * 100).round()}%',
                      window == 0 ? 'nothing yet' : '$hits of $window days',
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _monthCard(store, c, h),
                const SizedBox(height: 22),
                const SectionLabel('History'),
                Segmented<String>(
                  values: kRanges.map((r) => r.key).toList(),
                  labels: kRanges.map((r) => r.label).toList(),
                  value: range.key,
                  onChanged: (v) => store.mutate(() => store.habitRange = v),
                ),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _cardTitle(c, 'By month', 'days ticked'),
                    const SizedBox(height: 12),
                    SizedBox(height: 128, child: _bars(c, h, range, age)),
                  ]),
                ),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _cardTitle(
                      c,
                      range.allTime ? 'Since you started' : 'Last ${range.label.toLowerCase()}',
                      'one column is one week',
                    ),
                    const SizedBox(height: 14),
                    _heatmap(store, c, h, range, age),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cardTitle(AppColors c, String title, String hint) => Row(children: [
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt)),
        ),
        Text(hint, style: TextStyle(fontSize: 12, color: c.txt3)),
      ]);

  // ---------- the run, and the week it is made of ----------

  Widget _hero(BuildContext context, Store store, AppColors c, Habit h, int streak, bool isDone) {
    final today = todayKey();
    final now = clock();
    return Panel(
      color: washOf(c, c.acc),
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 16),
      child: Column(children: [
        Row(children: [
          IconTile(icon: iconFor(h.icon), tone: c.acc, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$streak',
                    key: const ValueKey('habit-streak'),
                    style: TextStyle(
                        fontSize: 40, height: 1, fontWeight: FontWeight.w800, letterSpacing: -1, color: c.txt)),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(streak == 1 ? 'day streak' : 'day streak',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt2)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.local_fire_department, size: 17, color: streak > 0 ? c.acc : c.txt3),
              ]),
              const SizedBox(height: 6),
              Text(
                isDone
                    ? 'Done for today'
                    : streak > 0
                        ? 'Tick today to keep it going'
                        : 'Tick today to start one',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDone ? c.acc : c.txt3),
              ),
            ]),
          ),
          CheckCircle(
            done: isDone,
            color: c.acc,
            size: 52,
            label: isDone ? 'Done today' : 'Mark today done',
            onTap: () {
              HapticFeedback.selectionClick();
              store.toggleHabit(h.id, today);
            },
          ),
        ]),
        const SizedBox(height: 16),
        // The last seven days, each one a button: yesterday's forgotten tick
        // is the commonest thing anyone comes to this page to fix.
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(children: [
            for (var back = 6; back >= 0; back--)
              Expanded(child: _weekDay(store, c, h, addDays(now, -back), back == 0)),
          ]),
        ),
      ]),
    );
  }

  Widget _weekDay(Store store, AppColors c, Habit h, DateTime day, bool isToday) {
    final key = dateKey(day);
    final hit = h.doneOn(key);
    return Semantics(
      button: true,
      checked: hit,
      label: '${weekdayName(day)} ${day.day}',
      child: GestureDetector(
        key: ValueKey('week-$key'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          store.toggleHabit(h.id, key);
        },
        child: Column(children: [
          Text(_weekdayInitials[day.weekday - 1],
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday ? c.txt : c.txt3)),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hit ? c.acc : c.surf,
              shape: BoxShape.circle,
              border: isToday && !hit ? Border.all(color: c.acc, width: 2) : null,
            ),
            child: Text('${day.day}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hit ? c.accTxt : c.txt2)),
          ),
        ]),
      ),
    );
  }

  Widget _stat(AppColors c, String label, String value, String caption) => Panel(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.txt3)),
          const SizedBox(height: 5),
          Text(value,
              key: ValueKey('habit-${label.toLowerCase()}'),
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.txt)),
          const SizedBox(height: 2),
          Text(caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: c.txt3)),
        ]),
      );

  // ---------- bars ----------

  Widget _bars(AppColors c, Habit h, HabitRange range, int age) {
    final now = clock();
    final bars = <({String label, int count, double ratio})>[];

    // All time shows every month since the first tick, up to a year of them:
    // more would be bars too thin to read.
    var count = range.bars;
    if (range.allTime) {
      final first = addDays(now, -(age > 0 ? age - 1 : 0));
      count = ((now.year - first.year) * 12 + now.month - first.month + 1).clamp(1, 12);
    }
    for (var i = count - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final len = DateTime(month.year, month.month + 1, 0).day;
      var n = 0;
      for (var d = 1; d <= len; d++) {
        if (h.doneOn(dateKey(DateTime(month.year, month.month, d)))) n++;
      }
      bars.add((label: monthShortLabel(month.month, count <= 6), count: n, ratio: n / len));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) SizedBox(width: bars.length > 8 ? 4 : 7),
          Expanded(
            child: Column(children: [
              // The number each bar stands for, so a bar never has to be
              // judged by eye against its neighbours.
              Text('${bars[i].count}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: bars[i].count == 0 ? c.txt3 : c.txt)),
              const SizedBox(height: 5),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: bars[i].count == 0 ? 0.05 : bars[i].ratio.clamp(0.09, 1.0),
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bars[i].count == 0
                            ? c.surf2
                            : (i == bars.length - 1 ? c.acc : c.acc.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(bars[i].label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.txt3)),
            ]),
          ),
        ],
      ],
    );
  }

  // ---------- one month as a calendar ----------

  /// A month at a time, laid out under its weekdays, every day a button.
  /// The arrows turn back through earlier months; there is nothing to turn
  /// forward to past the present one.
  Widget _monthCard(Store store, AppColors c, Habit h) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(now.year, now.month - _monthsBack, 1);
    final length = DateTime(first.year, first.month + 1, 0).day;
    final lead = store.sundayFirst ? first.weekday % 7 : first.weekday - 1;
    final order = store.sundayFirst ? [6, 0, 1, 2, 3, 4, 5] : [0, 1, 2, 3, 4, 5, 6];
    // Days that have come, so a month in progress is not marked down for the
    // days it has not reached.
    final reached = _monthsBack == 0 ? today.day : length;
    var ticked = 0;
    for (var d = 1; d <= length; d++) {
      if (h.doneOn(dateKey(DateTime(first.year, first.month, d)))) ticked++;
    }

    Widget arrow(IconData icon, String label, VoidCallback? onTap) => IconButton(
          key: ValueKey('month-$label'),
          tooltip: '$label month',
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 24, color: onTap == null ? c.txt3.withOpacity(0.35) : c.txt2),
        );

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${monthName(first.month)} ${first.year}',
                  key: const ValueKey('month-title'),
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: c.txt)),
              const SizedBox(height: 2),
              Text('$ticked of $reached days · tap a day to change it',
                  style: TextStyle(fontSize: 12, color: c.txt3)),
            ]),
          ),
          arrow(Icons.chevron_left, 'Previous', () => setState(() => _monthsBack++)),
          arrow(Icons.chevron_right, 'Next', _monthsBack == 0 ? null : () => setState(() => _monthsBack--)),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(children: [
            Row(children: [
              for (final i in order)
                Expanded(
                  child: Text(_weekdayInitials[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.txt3)),
                ),
            ]),
            const SizedBox(height: 8),
            for (var week = 0; week * 7 < lead + length; week++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: () {
                        final day = week * 7 + d - lead + 1;
                        if (day < 1 || day > length) return const SizedBox.shrink();
                        return _calendarDay(store, c, h, DateTime(first.year, first.month, day), today);
                      }(),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _calendarDay(Store store, AppColors c, Habit h, DateTime day, DateTime today) {
    final key = dateKey(day);
    final hit = h.doneOn(key);
    final isToday = day == today;
    final future = day.isAfter(today);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          key: ValueKey('day-$key'),
          behavior: HitTestBehavior.opaque,
          onTap: future
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  store.toggleHabit(h.id, key);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hit ? c.acc : (future ? Colors.transparent : c.surf2),
              borderRadius: BorderRadius.circular(12),
              border: isToday && !hit ? Border.all(color: c.acc, width: 2) : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hit ? c.accTxt : (future ? c.txt3.withOpacity(0.5) : c.txt2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- months as a heat map ----------

  /// Too many days to make buttons of: a picture of the run, read left to
  /// right, a column a week. Anything over half a year is cut into rows of
  /// half a year so its squares stay large enough to tell apart.
  Widget _heatmap(Store store, AppColors c, Habit h, HabitRange range, int age) {
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final shift = store.sundayFirst ? today.weekday % 7 : today.weekday - 1;
    final thisWeek = addDays(today, -shift);
    // All time runs from the first tick, but never fewer than three months
    // of squares nor more than two years of them.
    final weeks = range.allTime ? (age / 7).ceil().clamp(13, 104) : (range.days / 7).ceil();
    final perRow = weeks < 26 ? weeks : 26;
    final rows = (weeks / perRow).ceil();

    return Column(children: [
      for (var r = 0; r < rows; r++) ...[
        if (r > 0) const SizedBox(height: 16),
        LayoutBuilder(builder: (_, box) {
          // The oldest half comes first, each half ending perRow weeks
          // before the next one does.
          final lastWeek = addDays(thisWeek, -(rows - 1 - r) * perRow * 7);
          final firstWeek = addDays(lastWeek, -(perRow - 1) * 7);
          return _heatBlock(store, c, h, firstWeek, perRow, today, box.maxWidth);
        }),
      ],
    ]);
  }

  Widget _heatBlock(
      Store store, AppColors c, Habit h, DateTime firstWeek, int weeks, DateTime today, double width) {
    const labelWidth = 18.0;
    const gap = 2.5;
    final cell = ((width - labelWidth - gap * (weeks - 1)) / weeks).floorToDouble().clamp(4.0, 16.0);
    final pitch = cell + gap;

    // A month is named over the column that holds its first day. The block
    // usually opens part-way through a month; that one is named too, but only
    // when there is room before the next name begins.
    final opens = <int, int>{};
    for (var w = 0; w < weeks; w++) {
      final start = addDays(firstWeek, w * 7);
      final end = addDays(start, 6);
      if (start.day == 1) {
        opens[w] = start.month;
      } else if (end.month != start.month) {
        opens[w] = end.month;
      }
    }
    if (opens.keys.every((w) => w >= 3)) opens[0] = firstWeek.month;
    final monthLabels = [
      for (final w in opens.keys.toList()..sort())
        Positioned(
          left: labelWidth + w * pitch,
          top: 0,
          child: Text(monthShort(opens[w]!),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.txt3)),
        ),
    ];

    return SizedBox(
      width: width,
      height: 16 + 7 * pitch - gap,
      child: Stack(clipBehavior: Clip.none, children: [
        ...monthLabels,
        // Every other weekday is named; seven labels at this size would
        // only be a grey smear.
        for (final row in [0, 2, 4, 6])
          Positioned(
            left: 0,
            top: 16 + row * pitch + (cell - 11) / 2,
            child: Text(_weekdayInitials[addDays(firstWeek, row).weekday - 1],
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c.txt3)),
          ),
        for (var w = 0; w < weeks; w++)
          for (var d = 0; d < 7; d++)
            () {
              final day = addDays(firstWeek, w * 7 + d);
              if (day.isAfter(today)) return const SizedBox.shrink();
              final hit = h.doneOn(dateKey(day));
              return Positioned(
                left: labelWidth + w * pitch,
                top: 16 + d * pitch,
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    color: hit ? c.acc : c.surf2,
                    borderRadius: BorderRadius.circular(cell >= 9 ? 3 : 2),
                    border: day == today && !hit ? Border.all(color: c.acc, width: 1.5) : null,
                  ),
                ),
              );
            }(),
      ]),
    );
  }
}

String monthShortLabel(int month, bool long) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = ((month - 1) % 12 + 12) % 12;
  return long ? names[m] : names[m].substring(0, 1);
}

import 'package:flutter/material.dart';

import '../models.dart';
import '../sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final today = todayKey();
    final done = store.habits.where((h) => h.doneOn(today)).length;

    return Column(children: [
      ScreenTitle(title: 'Habits', subtitle: '$done/${store.habits.length} Completed Today'),
      Expanded(
        child: store.habits.isEmpty
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.local_fire_department,
                  title: 'Build a streak',
                  body: 'Add a habit and tick it off each day.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                itemCount: store.habits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 11),
                itemBuilder: (context, i) {
                  final h = store.habits[i];
                  final isDone = h.doneOn(today);
                  return Panel(
                    color: isDone ? c.accTint : c.surf,
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => store.toggleHabit(h.id, today),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isDone ? c.acc : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.acc, width: 2.5),
                          ),
                          child: isDone ? Icon(Icons.check, size: 18, color: c.accTxt) : null,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.txt)),
                          if (h.time != null) ...[
                            const SizedBox(height: 2),
                            Text(fmtMins(h.time!, store.use24), style: TextStyle(fontSize: 11.5, color: c.txt3)),
                          ],
                        ]),
                      ),
                      Icon(Icons.local_fire_department, size: 19, color: c.txt2),
                      const SizedBox(width: 4),
                      Text('${h.streak}',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt2)),
                      const SizedBox(width: 10),
                      Material(
                        color: c.accTint,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => HabitDetail(habitId: h.id)),
                          ),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.bar_chart, size: 19, color: c.acc),
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

class HabitDetail extends StatelessWidget {
  final String habitId;
  const HabitDetail({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final h = store.habits.firstWhereOrNull((x) => x.id == habitId);
    if (h == null) return const SizedBox.shrink();
    final range = kRanges.firstWhere((r) => r.key == store.habitRange, orElse: () => kRanges.first);
    final today = DateTime.now();

    final hitsInRange = List.generate(range.days, (i) => dateKey(today.subtract(Duration(days: i))))
        .where(h.doneOn)
        .length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 4),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.txt)),
              Expanded(
                child: Text(h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.txt)),
              ),
              GestureDetector(
                onTap: () => openHabitSheet(context, existing: h),
                child: Icon(Icons.edit, size: 20, color: c.txt2),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  store.deleteHabit(h.id);
                  Navigator.pop(context);
                },
                child: Icon(Icons.delete, size: 20, color: c.danger),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                Row(children: [
                  Expanded(child: _stat(c, 'STREAK', '${h.streak}')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(c, 'TOTAL', '${h.history.length}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(c, range.label.toUpperCase(),
                        '${(hitsInRange / range.days * 100).round()}%'),
                  ),
                ]),
                const SizedBox(height: 20),
                Segmented<String>(
                  values: kRanges.map((r) => r.key).toList(),
                  labels: kRanges.map((r) => r.label).toList(),
                  value: store.habitRange,
                  onChanged: (v) => store.mutate(() => store.habitRange = v),
                ),
                const SizedBox(height: 24),
                Text(range.monthly ? 'By month' : 'By week',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt2)),
                const SizedBox(height: 14),
                SizedBox(height: 92, child: _bars(c, h, range)),
                const SizedBox(height: 26),
                Row(children: [
                  Expanded(
                    child: Text('Last ${range.label.toLowerCase()}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt2)),
                  ),
                  Text(range.days > 40 ? 'one column = one week' : 'tap a day to change it',
                      style: TextStyle(fontSize: 12, color: c.txt3)),
                ]),
                const SizedBox(height: 14),
                _grid(store, c, h, range),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stat(AppColors c, String label, String value) => Panel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.txt3)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.txt)),
        ]),
      );

  Widget _bars(AppColors c, Habit h, HabitRange range) {
    final today = DateTime.now();
    final bars = <({String label, double ratio})>[];

    if (range.monthly) {
      for (var i = range.bars - 1; i >= 0; i--) {
        final month = DateTime(today.year, today.month - i, 1);
        final len = DateTime(month.year, month.month + 1, 0).day;
        var n = 0;
        for (var d = 1; d <= len; d++) {
          if (h.doneOn(dateKey(DateTime(month.year, month.month, d)))) n++;
        }
        bars.add((label: monthShortLabel(month.month, range.bars <= 6), ratio: n / len));
      }
    } else {
      for (var w = range.bars - 1; w >= 0; w--) {
        var n = 0;
        for (var d = 0; d < 7; d++) {
          if (h.doneOn(dateKey(today.subtract(Duration(days: w * 7 + d))))) n++;
        }
        bars.add((label: range.bars > 6 ? '$n' : '$n/7', ratio: n / 7));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                height: 10 + bars[i].ratio * 62,
                decoration: BoxDecoration(
                  color: i == bars.length - 1 ? c.acc : c.accTint,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 6),
              Text(bars[i].label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.txt3)),
            ]),
          ),
        ],
      ],
    );
  }

  /// Short ranges read as a calendar; long ones transpose to weekday rows so a
  /// year fits on one screen instead of 52 tall rows.
  Widget _grid(Store store, AppColors c, Habit h, HabitRange range) {
    final today = DateTime.now();
    final days = List.generate(range.days, (i) => today.subtract(Duration(days: range.days - 1 - i)));

    if (range.days <= 40) {
      return GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: range.gap,
        crossAxisSpacing: range.gap,
        children: [
          for (final d in days) _cell(store, c, h, d, null),
        ],
      );
    }

    final lead = (days.first.weekday - 1) % 7;
    final columns = <Widget>[];
    var index = -lead;
    while (index < days.length) {
      final column = <Widget>[];
      for (var row = 0; row < 7; row++) {
        final i = index + row;
        column.add(Padding(
          padding: EdgeInsets.only(bottom: row == 6 ? 0 : range.gap),
          child: i < 0 || i >= days.length
              ? SizedBox(width: range.cell, height: range.cell)
              : _cell(store, c, h, days[i], range.cell),
        ));
      }
      columns.add(Padding(
        padding: EdgeInsets.only(right: range.gap),
        child: Column(children: column),
      ));
      index += 7;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: columns),
    );
  }

  Widget _cell(Store store, AppColors c, Habit h, DateTime d, double? size) {
    final key = dateKey(d);
    final hit = h.doneOn(key);
    final isToday = key == todayKey();
    return GestureDetector(
      onTap: () => store.toggleHabit(h.id, key),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: hit ? c.acc : c.surf2,
          borderRadius: BorderRadius.circular(size == null ? 9 : (size >= 20 ? 6 : 2)),
          border: isToday ? Border.all(color: c.acc, width: 1.5) : null,
        ),
      ),
    );
  }
}

String monthShortLabel(int month, bool long) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = ((month - 1) % 12 + 12) % 12;
  return long ? names[m] : names[m].substring(0, 1);
}

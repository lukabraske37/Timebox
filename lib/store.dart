import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services.dart';

const _key = 'timebox.state';
const _schema = 1;

/// Vertical pixels per minute for each zoom step.
const Map<String, double> kZoom = {'compact': 0.45, 'normal': 0.85, 'roomy': 1.5};
const double kMinNode = 76;
const double kRowGap = 10;

class HabitRange {
  final String key;
  final String label;
  final int days;
  final bool monthly;
  final int bars;
  final double cell;
  final double gap;

  const HabitRange(this.key, this.label, this.days, this.monthly, this.bars, this.cell, this.gap);
}

const List<HabitRange> kRanges = [
  HabitRange('5w', '5 weeks', 35, false, 5, 42, 6),
  HabitRange('12w', '12 weeks', 84, false, 12, 24, 4),
  HabitRange('6m', '6 months', 182, true, 6, 11, 3),
  HabitRange('1y', 'Year', 364, true, 12, 6, 2),
];

class Store extends ChangeNotifier {
  // content
  List<Block> blocks = [];
  List<InboxItem> inbox = [];
  List<Task> tasks = [];
  List<Habit> habits = [];

  // where the user is
  bool booted = false;
  int tab = 0; // 0 inbox, 1 timeline, 2 tasks, 3 habits, 4 settings
  int weekOffset = 0;
  late DateTime selected;
  int now = nowMinutes();
  String? selectedBlockId;
  bool locked = false;

  // preferences
  String theme = 'dark';
  String accent = 'teal';
  bool use24 = false;
  bool sundayFirst = false;
  bool habitsFirst = false;
  bool blockColorIcons = true;
  bool classicTimeline = false;
  String zoom = 'normal';
  bool biometric = false;
  bool notifBlocks = true;
  bool notifTasks = true;
  bool notifHabits = true;
  bool dailySummary = false;
  int summaryTime = 1260;
  String habitRange = '5w';
  String seedDate = todayKey();

  Timer? _tick;
  Timer? _saveTimer;
  SharedPreferences? _prefs;

  Store() {
    selected = DateTime.now();
  }

  double get ppm => kZoom[zoom] ?? 0.85;
  String get selectedKey => dateKey(selected);
  bool get selectedIsToday => selectedKey == todayKey();
  Block? get selectedBlock =>
      selectedBlockId == null ? null : blocks.firstWhereOrNull((b) => b.id == selectedBlockId);

  // ---------- lifecycle ----------

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      _seedDemo();
    } else {
      try {
        _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seedDemo();
      }
    }
    _rollForward();
    locked = booted && biometric;
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _onTick());
    notifyListeners();
    await Notifications.init();
    _syncNotifications();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _onTick() {
    final n = nowMinutes();
    if (n == now) return;
    final crossedMidnight = n < now;
    now = n;
    if (crossedMidnight) {
      _rollForward();
      selected = DateTime.now();
      weekOffset = 0;
    }
    notifyListeners();
  }

  /// Carries the whole plan forward by however many days have passed, so the
  /// timeline is never empty just because the app sat unopened.
  void _rollForward() {
    final today = todayKey();
    if (seedDate == today) return;
    final days = keyToDate(today).difference(keyToDate(seedDate)).inDays;
    if (days > 0) {
      for (final b in blocks) {
        b.date = dateKey(keyToDate(b.date).add(Duration(days: days)));
      }
    }
    seedDate = today;
  }

  // ---------- persistence ----------

  Map<String, dynamic> toJson() => {
        'schema': _schema,
        'booted': booted,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'inbox': inbox.map((b) => b.toJson()).toList(),
        'tasks': tasks.map((b) => b.toJson()).toList(),
        'habits': habits.map((b) => b.toJson()).toList(),
        'theme': theme,
        'accent': accent,
        'use24': use24,
        'sundayFirst': sundayFirst,
        'habitsFirst': habitsFirst,
        'blockColorIcons': blockColorIcons,
        'classicTimeline': classicTimeline,
        'zoom': zoom,
        'biometric': biometric,
        'notifBlocks': notifBlocks,
        'notifTasks': notifTasks,
        'notifHabits': notifHabits,
        'dailySummary': dailySummary,
        'summaryTime': summaryTime,
        'habitRange': habitRange,
        'seedDate': seedDate,
      };

  void _fromJson(Map<String, dynamic> j) {
    booted = j['booted'] as bool? ?? false;
    blocks = ((j['blocks'] as List?) ?? []).map((e) => Block.fromJson(e as Map<String, dynamic>)).toList();
    inbox = ((j['inbox'] as List?) ?? []).map((e) => InboxItem.fromJson(e as Map<String, dynamic>)).toList();
    tasks = ((j['tasks'] as List?) ?? []).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    habits = ((j['habits'] as List?) ?? []).map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
    theme = j['theme'] as String? ?? 'dark';
    accent = j['accent'] as String? ?? 'teal';
    use24 = j['use24'] as bool? ?? false;
    sundayFirst = j['sundayFirst'] as bool? ?? false;
    habitsFirst = j['habitsFirst'] as bool? ?? false;
    blockColorIcons = j['blockColorIcons'] as bool? ?? true;
    classicTimeline = j['classicTimeline'] as bool? ?? false;
    zoom = j['zoom'] as String? ?? 'normal';
    biometric = j['biometric'] as bool? ?? false;
    notifBlocks = j['notifBlocks'] as bool? ?? true;
    notifTasks = j['notifTasks'] as bool? ?? true;
    notifHabits = j['notifHabits'] as bool? ?? true;
    dailySummary = j['dailySummary'] as bool? ?? false;
    summaryTime = (j['summaryTime'] as num?)?.toInt() ?? 1260;
    habitRange = j['habitRange'] as String? ?? '5w';
    seedDate = j['seedDate'] as String? ?? todayKey();
    if (blocks.isEmpty && inbox.isEmpty && tasks.isEmpty && habits.isEmpty) _seedDemo();
  }

  void save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), () {
      _prefs?.setString(_key, jsonEncode(toJson()));
      _syncNotifications();
    });
  }

  void _syncNotifications() {
    Notifications.sync(
      blocks: blocks,
      tasks: tasks,
      habits: habits,
      blocksOn: notifBlocks,
      tasksOn: notifTasks,
      habitsOn: notifHabits,
      summaryOn: dailySummary,
      summaryTime: summaryTime,
      use24: use24,
    );
  }

  void mutate(void Function() fn) {
    fn();
    notifyListeners();
    save();
  }

  Future<void> restore(Map<String, dynamic> data) async {
    _fromJson(data);
    _rollForward();
    booted = true;
    notifyListeners();
    save();
  }

  void resetDemo() {
    mutate(() {
      _seedDemo();
      booted = true;
      selectedBlockId = null;
    });
  }

  // ---------- days ----------

  DateTime get weekStart {
    final today = DateTime.now();
    final shift = sundayFirst ? today.weekday % 7 : today.weekday - 1;
    return DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: shift))
        .add(Duration(days: weekOffset * 7));
  }

  List<DateTime> get weekDays => List.generate(7, (i) => weekStart.add(Duration(days: i)));

  List<Block> blocksOn(String key) {
    final list = blocks.where((b) => b.date == key).toList();
    list.sort((a, b) => a.start == b.start ? a.end.compareTo(b.end) : a.start.compareTo(b.start));
    return list;
  }

  int nextFreeStart() {
    final list = blocksOn(selectedKey);
    return list.isEmpty ? 540 : list.last.end;
  }

  /// Empty time takes real height, so a three-hour gap looks like three hours.
  TimelineLayout layout() {
    final list = blocksOn(selectedKey);
    if (list.isEmpty) {
      return TimelineLayout(rows: [], trackHeight: 0, origin: 540, ppm: ppm, first: 0, last: 0);
    }
    if (classicTimeline) {
      var y = 0.0;
      int? prevEnd;
      final rows = <LaidOutBlock>[];
      for (final b in list) {
        final h = (44 + b.duration * 0.6).clamp(kMinNode, 150).toDouble();
        rows.add(LaidOutBlock(
          block: b,
          y: y,
          height: h,
          overlaps: prevEnd != null && b.start < prevEnd,
        ));
        prevEnd = b.end;
        y += h + 26;
      }
      return TimelineLayout(
          rows: rows, trackHeight: y + 10, origin: list.first.start, ppm: ppm, first: list.first.start, last: list.last.end);
    }

    var origin = list.first.start - 30;
    if (selectedIsToday && now > list.first.start - 30 && now < list.first.start) origin = now - 15;
    origin = (origin < 0 ? 0 : (origin ~/ 15) * 15);

    var prevBottom = -1e9;
    int? prevEnd;
    final rows = <LaidOutBlock>[];
    for (final b in list) {
      final h = (b.duration * ppm).clamp(kMinNode, 100000).toDouble();
      var y = (b.start - origin) * ppm;
      final overlaps = prevEnd != null && b.start < prevEnd;
      if (y < prevBottom + kRowGap) y = prevBottom + kRowGap;
      prevBottom = y + h;
      prevEnd = b.end;
      rows.add(LaidOutBlock(block: b, y: y, height: h, overlaps: overlaps));
    }
    return TimelineLayout(
      rows: rows,
      trackHeight: prevBottom + 40,
      origin: origin,
      ppm: ppm,
      first: list.first.start,
      last: list.last.end,
    );
  }

  // ---------- edits ----------

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  void moveBlock(String id, int minutes) => mutate(() {
        final b = blocks.firstWhereOrNull((x) => x.id == id);
        if (b == null) return;
        final dur = b.duration;
        final start = (b.start + minutes).clamp(0, 1440 - dur);
        b.start = start;
        b.end = start + dur;
      });

  void stretchBlock(String id, int minutes) => mutate(() {
        final b = blocks.firstWhereOrNull((x) => x.id == id);
        if (b == null) return;
        b.end = (b.end + minutes).clamp(b.start + 5, 1440);
      });

  void deleteBlock(String id) => mutate(() {
        blocks.removeWhere((b) => b.id == id);
        if (selectedBlockId == id) selectedBlockId = null;
      });

  void addBlock(Block b) => mutate(() => blocks.add(b));

  void replaceBlock(Block b) => mutate(() {
        final i = blocks.indexWhere((x) => x.id == b.id);
        if (i >= 0) blocks[i] = b;
      });

  /// Inbox entries are templates: scheduling one leaves it in the list.
  Block scheduleFromInbox(InboxItem item) {
    final start = nextFreeStart();
    final b = Block(
      id: _id(),
      date: selectedKey,
      icon: item.icon,
      title: item.title,
      start: start,
      end: start + item.dur,
    );
    addBlock(b);
    return b;
  }

  void addInbox(InboxItem i) => mutate(() => inbox.add(i));
  void replaceInbox(InboxItem i) => mutate(() {
        final idx = inbox.indexWhere((x) => x.id == i.id);
        if (idx >= 0) inbox[idx] = i;
      });
  void deleteInbox(String id) => mutate(() => inbox.removeWhere((x) => x.id == id));

  void addTask(Task t) => mutate(() => tasks.add(t));
  void replaceTask(Task t) => mutate(() {
        final i = tasks.indexWhere((x) => x.id == t.id);
        if (i >= 0) tasks[i] = t;
      });
  void deleteTask(String id) => mutate(() => tasks.removeWhere((x) => x.id == id));
  void toggleTask(String id) => mutate(() {
        final t = tasks.firstWhereOrNull((x) => x.id == id);
        if (t != null) t.done = !t.done;
      });
  void clearDoneTasks() => mutate(() => tasks.removeWhere((t) => t.done));

  void addHabit(Habit h) => mutate(() => habits.add(h));
  void deleteHabit(String id) => mutate(() => habits.removeWhere((x) => x.id == id));
  void toggleHabit(String id, String day) => mutate(() {
        final h = habits.firstWhereOrNull((x) => x.id == id);
        if (h == null) return;
        if (h.history[day] == true) {
          h.history.remove(day);
        } else {
          h.history[day] = true;
        }
      });

  String newId() => _id();

  // ---------- demo content ----------

  void _seedDemo() {
    final today = todayKey();
    final tomorrow = dateKey(DateTime.now().add(const Duration(days: 1)));
    seedDate = today;
    blocks = [
      Block(id: 'b1', date: today, icon: 'directions_run', title: 'Morning run', start: 420, end: 465, repeat: 'Daily', alerts: ['At start of task']),
      Block(id: 'b2', date: today, icon: 'laptop_mac', title: 'Deep work: pricing page', start: 540, end: 630, alerts: ['At start of task']),
      Block(id: 'b3', date: today, icon: 'groups', title: 'Standup', start: 720, end: 735, color: 4, repeat: 'Daily', alerts: ['15m before start']),
      Block(id: 'b4', date: today, icon: 'restaurant', title: 'Lunch with Nina', start: 720, end: 765, color: 1),
      Block(id: 'b5', date: today, icon: 'directions_car', title: 'School run', start: 930, end: 960, color: 2, repeat: 'Weekly', alerts: ['15m before start']),
      Block(id: 'b6', date: today, icon: 'fitness_center', title: 'Gym', start: 1110, end: 1170, color: 3, repeat: 'Weekly'),
      Block(id: 'b7', date: tomorrow, icon: 'call', title: 'Call with the accountant', start: 600, end: 645, color: 5),
    ];
    inbox = [
      InboxItem(id: 'i1', icon: 'pets', title: 'Walk the dog', dur: 30),
      InboxItem(id: 'i2', icon: 'fitness_center', title: 'Gym', dur: 60),
      InboxItem(id: 'i3', icon: 'directions_car', title: 'School run', dur: 30),
      InboxItem(id: 'i4', icon: 'local_cafe', title: 'Coffee break', dur: 15),
    ];
    tasks = [
      Task(id: 't1', title: 'Pay the electricity bill', time: 1080),
      Task(id: 't2', title: 'Renew passport'),
      Task(id: 't3', title: 'Water the plants', done: true),
      Task(id: 't4', title: 'Send the invoice', time: 600),
    ];
    habits = [
      Habit(id: 'h1', title: 'Read 20 pages', icon: 'book', time: 1350, history: _history([1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 22, 24, 25, 26, 27, 28, 30, 0])),
      Habit(id: 'h2', title: 'Stretch', icon: 'self_improvement', history: _history([1, 2, 3, 4, 7, 8, 9, 11, 14, 15, 18, 21, 22, 25, 28])),
      Habit(id: 'h3', title: 'Gym', icon: 'fitness_center', time: 1110, history: _history([1, 3, 5, 6, 8, 10, 12, 13, 15, 17, 19, 20, 22, 24, 26, 27, 29])),
      Habit(id: 'h4', title: 'No phone after 22:00', icon: 'bedtime', time: 1320, history: _history([1, 2, 5, 6, 9, 13, 16, 20, 23, 27])),
    ];
  }

  Map<String, bool> _history(List<int> daysAgo) {
    final now = DateTime.now();
    return {for (final d in daysAgo) dateKey(now.subtract(Duration(days: d))): true};
  }
}

extension FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

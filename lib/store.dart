import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services.dart';

const _key = 'timebox.state';
const _schema = 1;

/// The state as it last loaded cleanly — the first thing to fall back on if
/// the main copy ever fails to parse.
const _bakKey = 'timebox.state.bak';

/// Whatever was on disk when a load failed, kept untouched so nothing is ever
/// thrown away just because this version could not read it.
const _corruptKey = 'timebox.state.corrupt';

/// One copy of the state per day it was opened, newest [kSnapshotsKept] kept.
const _snapPrefix = 'timebox.snap.';
const _beforeRestore = 'before-restore';
const int kSnapshotsKept = 7;

/// A saved copy the user can go back to.
class Snapshot {
  /// A date key, or [_beforeRestore] for the copy taken just before the last
  /// restore replaced everything.
  final String id;
  final int blocks;
  final int tasks;
  final int habits;
  final int inbox;

  const Snapshot(this.id, this.blocks, this.tasks, this.habits, this.inbox);

  bool get isBeforeRestore => id == _beforeRestore;
}

/// Vertical pixels per minute for each zoom step.
const Map<String, double> kZoom = {'compact': 0.45, 'normal': 0.85, 'roomy': 1.5};

/// Shortest a block may be drawn, per zoom step. A block shorter than this is
/// stretched to stay readable, which costs the day some of its true shape — so
/// the tighter the zoom, the less it is allowed to cheat.
const Map<String, double> kMinNode = {'compact': 52, 'normal': 62, 'roomy': 78};
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

  /// When a backup file was last written out of the app, as an ISO timestamp.
  String? lastBackupAt;

  /// Set when loading had to fall back on an older copy, so the app can say so
  /// instead of quietly showing data that is a day behind.
  String? loadNotice;

  /// Called after something was removed that [undo] can bring back.
  void Function(String label)? onUndoable;
  String? _undoState;

  /// When the app last went to the background, for deciding whether to lock.
  DateTime? _leftAt;

  /// The calendar day the view is anchored to, so a day change can be told
  /// apart from the user simply browsing to another date.
  String _viewDay = todayKey();

  Timer? _tick;
  Timer? _saveTimer;
  SharedPreferences? _prefs;

  /// Tests switch notifications off: the scheduler talks to Android, and
  /// there is no Android under a unit test to answer it.
  final bool notifications;

  Store({this.notifications = true}) {
    selected = DateTime.now();
  }

  double get ppm => kZoom[zoom] ?? 0.85;
  double get minNode => kMinNode[zoom] ?? 62;
  String get selectedKey => dateKey(selected);
  bool get selectedIsToday => selectedKey == todayKey();
  /// Occurrences of a repeating block are built per day and are not in the
  /// stored list, so look through what the selected day actually shows.
  Block? get selectedBlock => selectedBlockId == null
      ? null
      : blocksOn(selectedKey).firstWhereOrNull((b) => b.id == selectedBlockId);

  // ---------- lifecycle ----------

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      _seedDemo();
    } else if (_tryLoad(raw)) {
      // It read cleanly, so it becomes the copy to fall back on next time.
      await _prefs!.setString(_bakKey, raw);
      await _snapshot(todayKey(), raw, overwrite: false);
    } else {
      // Never overwrite what could not be read: park it, then work back
      // through the older copies until one loads.
      await _prefs!.setString(_corruptKey, raw);
      final older = <String?>[
        _prefs!.getString(_bakKey),
        for (final snap in snapshots()) _prefs!.getString('$_snapPrefix${snap.id}'),
      ];
      final recovered = older.any((copy) => copy != null && _tryLoad(copy));
      if (recovered) {
        loadNotice = 'Your latest save could not be read, so an earlier copy was restored.';
      } else {
        _clearContent();
        loadNotice = 'Your saved data could not be read. It has been kept aside, not deleted.';
      }
    }
    _viewDay = todayKey();
    selected = DateTime.now();
    locked = booted && biometric;
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => _onTick());
    notifyListeners();
    if (!notifications) return;
    await Notifications.init();
    _syncNotifications();
  }

  bool _tryLoad(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return false;
      _fromJson(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _clearContent() {
    blocks = [];
    inbox = [];
    tasks = [];
    habits = [];
  }

  @override
  void dispose() {
    _tick?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (nowMinutes() == now && todayKey() == _viewDay) return;
    syncToToday();
  }

  /// Follows the clock onto the new day — at midnight with the app open, and
  /// when it comes back after being away. Browsing to another date on the same
  /// day is left alone: only a real change of date moves the view.
  void syncToToday() {
    now = nowMinutes();
    final today = todayKey();
    if (today != _viewDay) {
      _viewDay = today;
      selected = DateTime.now();
      weekOffset = 0;
      selectedBlockId = null;
      _syncNotifications();
    }
    notifyListeners();
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
        'lastBackupAt': lastBackupAt,
      };

  /// One entry that will not parse is dropped on its own rather than taking
  /// the whole list — and with it the whole load — down with it.
  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    final out = <T>[];
    if (raw is! List) return out;
    for (final e in raw) {
      try {
        out.add(parse(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    return out;
  }

  static bool _flag(Object? v, bool fallback) => v is bool ? v : fallback;
  static String _text(Object? v, String fallback) => v is String ? v : fallback;

  void _fromJson(Map<String, dynamic> j) {
    booted = _flag(j['booted'], false);
    blocks = _list(j['blocks'], Block.fromJson);
    inbox = _list(j['inbox'], InboxItem.fromJson);
    tasks = _list(j['tasks'], Task.fromJson);
    habits = _list(j['habits'], Habit.fromJson);
    theme = _text(j['theme'], 'dark');
    accent = _text(j['accent'], 'teal');
    use24 = _flag(j['use24'], false);
    sundayFirst = _flag(j['sundayFirst'], false);
    habitsFirst = _flag(j['habitsFirst'], false);
    blockColorIcons = _flag(j['blockColorIcons'], true);
    classicTimeline = _flag(j['classicTimeline'], false);
    zoom = kZoom.containsKey(j['zoom']) ? j['zoom'] as String : 'normal';
    biometric = _flag(j['biometric'], false);
    notifBlocks = _flag(j['notifBlocks'], true);
    notifTasks = _flag(j['notifTasks'], true);
    notifHabits = _flag(j['notifHabits'], true);
    dailySummary = _flag(j['dailySummary'], false);
    final summary = j['summaryTime'];
    summaryTime = summary is num ? summary.toInt().clamp(0, 1439) : 1260;
    habitRange = kRanges.any((r) => r.key == j['habitRange']) ? j['habitRange'] as String : '5w';
    lastBackupAt = j['lastBackupAt'] is String ? j['lastBackupAt'] as String : null;
  }

  void save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _writeNow);
  }

  void _writeNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _prefs?.setString(_key, jsonEncode(toJson()));
    _syncNotifications();
  }

  /// Writes anything still waiting on the save timer. Android may kill the
  /// app the moment it leaves the screen, so this runs on the way out.
  void flush() {
    if (_saveTimer != null) _writeNow();
  }

  // ---------- copies to go back to ----------

  Future<void> _snapshot(String id, String raw, {bool overwrite = true}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final key = '$_snapPrefix$id';
    if (!overwrite && prefs.containsKey(key)) return;
    await prefs.setString(key, raw);
    // Date keys sort oldest first, so everything before the last few goes.
    final dated = prefs.getKeys().where((k) => k.startsWith(_snapPrefix) && !k.endsWith(_beforeRestore)).toList()
      ..sort();
    for (final old in dated.take((dated.length - kSnapshotsKept).clamp(0, dated.length))) {
      await prefs.remove(old);
    }
  }

  /// Saved copies, newest first, with the one taken before the last restore
  /// at the top.
  List<Snapshot> snapshots() {
    final prefs = _prefs;
    if (prefs == null) return [];
    final ids = prefs.getKeys().where((k) => k.startsWith(_snapPrefix)).map((k) => k.substring(_snapPrefix.length)).toList()
      ..sort((a, b) => a == _beforeRestore ? -1 : (b == _beforeRestore ? 1 : b.compareTo(a)));
    final out = <Snapshot>[];
    for (final id in ids) {
      try {
        final j = jsonDecode(prefs.getString('$_snapPrefix$id')!) as Map<String, dynamic>;
        int n(String k) => j[k] is List ? (j[k] as List).length : 0;
        out.add(Snapshot(id, n('blocks'), n('tasks'), n('habits'), n('inbox')));
      } catch (_) {}
    }
    return out;
  }

  Future<bool> restoreSnapshot(String id) async {
    final raw = _prefs?.getString('$_snapPrefix$id');
    if (raw == null) return false;
    try {
      return await restore(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
  }

  /// Whether [data] is recognisably a Timebox backup rather than some other
  /// JSON file picked by mistake.
  static bool looksLikeBackup(Object? data) {
    if (data is! Map) return false;
    const lists = ['blocks', 'inbox', 'tasks', 'habits'];
    return lists.any((k) => data[k] is List) && lists.every((k) => data[k] == null || data[k] is List);
  }

  /// How many of each thing a backup holds, for showing before it is restored.
  static ({int blocks, int tasks, int habits, int inbox}) countsIn(Map<String, dynamic> data) {
    int n(String k) => data[k] is List ? (data[k] as List).length : 0;
    return (blocks: n('blocks'), tasks: n('tasks'), habits: n('habits'), inbox: n('inbox'));
  }

  /// Replaces everything with [data]. What was there is kept as a snapshot
  /// first, so a restore from the wrong file can itself be undone.
  Future<bool> restore(Map<String, dynamic> data) async {
    if (!looksLikeBackup(data)) return false;
    await _snapshot(_beforeRestore, jsonEncode(toJson()));
    // The lock belongs to this phone, not to the file being loaded.
    final lock = biometric;
    _fromJson(data);
    biometric = lock;
    _viewDay = todayKey();
    booted = true;
    selectedBlockId = null;
    _undoState = null;
    notifyListeners();
    _writeNow();
    return true;
  }

  /// Wipes blocks, tasks, habits and the inbox, keeping settings. A snapshot
  /// is taken first.
  Future<void> eraseAll() async {
    await _snapshot(_beforeRestore, jsonEncode(toJson()));
    mutate(() {
      _clearContent();
      selectedBlockId = null;
      _undoState = null;
    });
  }

  void markBackedUp() => mutate(() => lastBackupAt = DateTime.now().toIso8601String());

  /// Whole days since a backup file last left the app, or null if never.
  int? get daysSinceBackup {
    final at = lastBackupAt == null ? null : DateTime.tryParse(lastBackupAt!);
    return at == null ? null : DateTime.now().difference(at).inDays;
  }

  // ---------- undo ----------

  /// Remembers the content as it stands, then tells the app there is
  /// something to undo. Call it just before removing anything.
  void _undoable(String label) {
    _undoState = jsonEncode({
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'inbox': inbox.map((b) => b.toJson()).toList(),
      'tasks': tasks.map((b) => b.toJson()).toList(),
      'habits': habits.map((b) => b.toJson()).toList(),
    });
    onUndoable?.call(label);
  }

  bool get canUndo => _undoState != null;

  /// Puts back whatever the last removal took away.
  void undo() {
    final raw = _undoState;
    if (raw == null) return;
    _undoState = null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    mutate(() {
      blocks = _list(j['blocks'], Block.fromJson);
      inbox = _list(j['inbox'], InboxItem.fromJson);
      tasks = _list(j['tasks'], Task.fromJson);
      habits = _list(j['habits'], Habit.fromJson);
    });
  }

  // ---------- lock ----------

  /// Away for longer than this and the lock comes back on.
  static const lockAfter = Duration(seconds: 30);

  void leftApp() {
    flush();
    _leftAt ??= DateTime.now();
  }

  void cameBack() {
    final left = _leftAt;
    _leftAt = null;
    if (biometric && booted && left != null && DateTime.now().difference(left) >= lockAfter) {
      locked = true;
    }
    syncToToday();
  }

  void _syncNotifications() {
    if (!notifications) return;
    // Repeating blocks only exist as copies on the days they land on, so hand
    // the scheduler the next few days as they are actually planned.
    final upcoming = <Block>[];
    for (var i = 0; i < 8; i++) {
      upcoming.addAll(blocksOn(dateKey(DateTime.now().add(Duration(days: i)))));
    }
    Notifications.sync(
      blocks: upcoming,
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

  // ---------- days ----------

  DateTime get weekStart {
    final today = DateTime.now();
    final shift = sundayFirst ? today.weekday % 7 : today.weekday - 1;
    return DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: shift))
        .add(Duration(days: weekOffset * 7));
  }

  List<DateTime> get weekDays => List.generate(7, (i) => weekStart.add(Duration(days: i)));

  /// Everything planned for [key]: the blocks actually filed on that date,
  /// plus the copies any repeating block casts forward onto it.
  List<Block> blocksOn(String key) {
    final day = keyToDate(key);
    final list = <Block>[];
    for (final b in blocks) {
      if (b.date == key) {
        list.add(b);
      } else if (_repeatsOnto(b, key, day)) {
        list.add(b.occurrenceOn(key));
      }
    }
    list.sort((a, b) => a.start == b.start ? a.end.compareTo(b.end) : a.start.compareTo(b.start));
    return list;
  }

  bool _repeatsOnto(Block b, String key, DateTime day) {
    if (b.repeat == 'Once' || b.skips.contains(key)) return false;
    final from = keyToDate(b.date);
    if (!day.isAfter(from)) return false;
    switch (b.repeat) {
      case 'Daily':
        return true;
      case 'Weekly':
        return day.difference(from).inDays % 7 == 0;
      case 'Monthly':
        return day.day == from.day;
      default:
        return false;
    }
  }

  /// A repeating block shows up on later days as a copy that is not in the
  /// stored list. Changing one of those has to leave the rest of the series
  /// alone, so the copy becomes a block of its own for that day and the series
  /// is told to skip that date.
  Block? _detach(String id) {
    if (!id.contains(kOccurrenceMark)) return blocks.firstWhereOrNull((b) => b.id == id);
    final parts = id.split(kOccurrenceMark);
    final origin = blocks.firstWhereOrNull((b) => b.id == parts.first);
    if (origin == null) return null;
    final key = parts.last;
    if (!origin.skips.contains(key)) origin.skips.add(key);
    final copy = origin.occurrenceOn(key)
      ..id = _id()
      ..repeat = 'Once';
    blocks.add(copy);
    if (selectedBlockId == id) selectedBlockId = copy.id;
    return copy;
  }

  /// Where a new block should start: straight after whatever is already
  /// planned that day, so one block follows another. On an empty day it opens
  /// at nine, and on today it never suggests a time that has already passed.
  /// How the selected day stands: how many blocks, how much of it is planned,
  /// and how much of the waking stretch it covers is still free.
  ({int count, int planned, int free}) daySummary() {
    final list = blocksOn(selectedKey);
    if (list.isEmpty) return (count: 0, planned: 0, free: 0);
    var planned = 0;
    var last = list.first.start;
    var free = 0;
    for (final b in list) {
      planned += b.duration;
      if (b.start > last) free += b.start - last;
      if (b.end > last) last = b.end;
    }
    return (count: list.length, planned: planned, free: free);
  }

  int nextFreeStart() {
    final list = blocksOn(selectedKey);
    var start = 540;
    if (list.isNotEmpty) {
      // Follow the day as planned, even when it runs early — blocking out
      // 6:30 to 6:31 should hand the next block 6:31, not the morning default.
      start = list.first.end;
      for (final b in list) {
        if (b.end > start) start = b.end;
      }
      // A one minute block ending at 9:01 would otherwise hand the next block
      // 9:01, and every five minute step from there keeps the stray minute.
      start = snapUpToStep(start);
    }
    if (selectedIsToday) {
      final soon = snapUpToStep(now);
      if (soon > start) start = soon;
    }
    return start.clamp(0, 1435);
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
        final h = (44 + b.duration * 0.6).clamp(minNode, 150).toDouble();
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

    // Each block keeps the place in the day its time gives it. Blocks that
    // land on top of one another are split into side-by-side columns instead
    // of being pushed down, so two things at once read as two things at once.
    final placed = <({Block block, double y, double height, bool overlaps})>[];
    int? prevEnd;
    for (final b in list) {
      final h = (b.duration * ppm).clamp(minNode, 100000).toDouble();
      final y = ((b.start - origin) * ppm).toDouble();
      placed.add((block: b, y: y, height: h, overlaps: prevEnd != null && b.start < prevEnd));
      if (prevEnd == null || b.end > prevEnd) prevEnd = b.end;
    }

    // Group by time, not by drawn height: things that genuinely run at once
    // share the width, and a block that merely sits close to another keeps the
    // whole of it.
    final columnOf = List<int>.filled(placed.length, 0);
    final widthOf = List<int>.filled(placed.length, 1);
    var i = 0;
    while (i < placed.length) {
      var clusterEnd = placed[i].block.end;
      var j = i + 1;
      while (j < placed.length && placed[j].block.start < clusterEnd) {
        if (placed[j].block.end > clusterEnd) clusterEnd = placed[j].block.end;
        j++;
      }

      // The first column free by the time a block starts takes it, so a column
      // is reused once what was in it has finished.
      final freeFrom = <int>[];
      for (var k = i; k < j; k++) {
        var slot = freeFrom.indexWhere((t) => placed[k].block.start >= t);
        if (slot < 0) {
          freeFrom.add(0);
          slot = freeFrom.length - 1;
        }
        freeFrom[slot] = placed[k].block.end;
        columnOf[k] = slot;
      }
      for (var k = i; k < j; k++) {
        widthOf[k] = freeFrom.length;
      }
      i = j;
    }

    // Short blocks are stretched to stay readable, which can make two of them
    // collide even when their times do not. Push a block down only past the
    // ones whose slot it actually shares.
    final ys = [for (final p in placed) p.y];
    for (var k = 0; k < placed.length; k++) {
      for (var e = 0; e < k; e++) {
        final sharesSlot = columnOf[k] / widthOf[k] < (columnOf[e] + 1) / widthOf[e] &&
            columnOf[e] / widthOf[e] < (columnOf[k] + 1) / widthOf[k];
        if (!sharesSlot) continue;
        final floor = ys[e] + placed[e].height + kRowGap;
        if (ys[k] < floor) ys[k] = floor;
      }
    }

    final rows = <LaidOutBlock>[
      for (var k = 0; k < placed.length; k++)
        LaidOutBlock(
          block: placed[k].block,
          y: ys[k],
          height: placed[k].height,
          overlaps: placed[k].overlaps,
          column: columnOf[k],
          columns: widthOf[k],
        ),
    ];

    return TimelineLayout(
      rows: rows,
      trackHeight: rows.fold<double>(0, (m, r) => r.y + r.height > m ? r.y + r.height : m) + 40,
      origin: origin,
      ppm: ppm,
      first: list.first.start,
      last: list.last.end,
    );
  }

  // ---------- edits ----------

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  void moveBlock(String id, int minutes) => mutate(() {
        final b = _detach(id);
        if (b == null) return;
        final dur = b.duration;
        // Snapping here also heals a block already sitting off the grid.
        final start = snapToStep(b.start + minutes).clamp(0, 1440 - dur);
        b.start = start;
        b.end = start + dur;
      });

  void stretchBlock(String id, int minutes) => mutate(() {
        final b = _detach(id);
        if (b == null) return;
        b.end = snapToStep(b.end + minutes).clamp(b.start + kStep, 1440);
      });

  void deleteBlock(String id) {
    _undoable('Block deleted');
    mutate(() {
        if (id.contains(kOccurrenceMark)) {
          // Dropping one occurrence only takes that day out of the series.
          final parts = id.split(kOccurrenceMark);
          final origin = blocks.firstWhereOrNull((b) => b.id == parts.first);
          if (origin != null && !origin.skips.contains(parts.last)) {
            origin.skips.add(parts.last);
          }
        } else {
          blocks.removeWhere((b) => b.id == id);
        }
        if (selectedBlockId == id) selectedBlockId = null;
      });
  }

  void addBlock(Block b) => mutate(() => blocks.add(b));

  void replaceBlock(Block b) => mutate(() {
        if (b.id.contains(kOccurrenceMark)) {
          final parts = b.id.split(kOccurrenceMark);
          final origin = blocks.firstWhereOrNull((x) => x.id == parts.first);
          if (origin != null && !origin.skips.contains(parts.last)) {
            origin.skips.add(parts.last);
          }
          b.id = _id();
          b.repeat = 'Once';
          blocks.add(b);
          if (selectedBlockId != null) selectedBlockId = b.id;
          return;
        }
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
  void deleteInbox(String id) {
    _undoable('Removed from Inbox');
    mutate(() => inbox.removeWhere((x) => x.id == id));
  }

  void addTask(Task t) => mutate(() => tasks.add(t));
  void replaceTask(Task t) => mutate(() {
        final i = tasks.indexWhere((x) => x.id == t.id);
        if (i >= 0) tasks[i] = t;
      });
  void deleteTask(String id) {
    _undoable('Task deleted');
    mutate(() => tasks.removeWhere((x) => x.id == id));
  }
  void toggleTask(String id) => mutate(() {
        final t = tasks.firstWhereOrNull((x) => x.id == id);
        if (t != null) t.done = !t.done;
      });
  void clearDoneTasks() {
    if (!tasks.any((t) => t.done)) return;
    _undoable('Completed tasks cleared');
    mutate(() => tasks.removeWhere((t) => t.done));
  }

  void addHabit(Habit h) => mutate(() => habits.add(h));
  void deleteHabit(String id) {
    _undoable('Habit deleted');
    mutate(() => habits.removeWhere((x) => x.id == id));
  }
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
      Task(id: 't1', title: 'Pay the electricity bill', time: 1080, date: today),
      Task(id: 't2', title: 'Renew passport'),
      Task(id: 't3', title: 'Water the plants', done: true),
      Task(id: 't4', title: 'Send the invoice', time: 600, date: dateKey(DateTime.now().add(const Duration(days: 2)))),
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

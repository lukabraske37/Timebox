/// Plain data + the small helpers every screen shares.
library;

/// Times move in five minute steps everywhere — the wheels, the steppers, the
/// nudges on the action bar. A start that falls off that grid can never be
/// brought back onto it, since every step keeps the same remainder.
/// Shown in Settings. The build number is stamped in by the release workflow.
const String kAppVersion = '1.3';
const String kAppBuild = String.fromEnvironment('BUILD', defaultValue: 'dev');

const int kStep = 5;

/// The app's clock. Everything that asks what day or time it is asks this, so
/// a test can stand on a particular day — the night the clocks go back, say —
/// instead of waiting for one to come round.
DateTime Function() clock = DateTime.now;

/// How long Snooze puts an alarm off for.
const int kSnoozeMinutes = 10;

/// The application id the release is built with. A sound file of the user's
/// own is handed to Android by an address that starts with it.
const String kAndroidPackage = 'com.timebox.timebox';

/// One of the sounds an alarm can ring with. Each is a file in assets/sounds:
/// the app plays it from there as a preview, and the build copies it into the
/// Android resources, where the system plays it as the alarm itself.
class AlarmSound {
  final String key;
  final String name;
  final String about;

  const AlarmSound(this.key, this.name, this.about);

  String get resource => 'alarm_$key';
  String get asset => 'sounds/alarm_$key.ogg';
}

/// The phone's own alarm sound, whatever its owner has set that to.
const String kSystemSound = 'system';

/// A sound file the user picked themselves.
const String kCustomSound = 'custom';

const List<AlarmSound> kAlarmSounds = [
  AlarmSound('classic', 'Classic', 'Four beeps and a pause'),
  AlarmSound('digital', 'Digital', 'The trill of a wristwatch'),
  AlarmSound('chime', 'Chime', 'A run on a glockenspiel'),
  AlarmSound('marimba', 'Marimba', 'A warm mallet tune'),
  AlarmSound('harp', 'Harp', 'A plucked run upward'),
  AlarmSound('sunrise', 'Sunrise', 'A slow, gentle swell'),
  AlarmSound('birds', 'Birds', 'Birdsong at the window'),
  AlarmSound('bell', 'Bell', 'Two strokes of a large bell'),
  AlarmSound('pulse', 'Pulse', 'Urgent rising sweeps'),
];

/// What an alarm rings with, worked out to what Android needs. Android fixes
/// a notification channel's sound when the channel is first made, so every
/// sound gets a channel of its own.
class AlarmVoice {
  final String channel;
  final String label;

  /// A sound built into the app, by resource name.
  final String? resource;

  /// Any other sound, by address.
  final String? uri;

  const AlarmVoice({required this.channel, required this.label, this.resource, this.uri});

  static const system = AlarmVoice(
    channel: 'timebox_alarm',
    label: 'Timebox alarms',
    uri: 'content://settings/system/alarm_alert',
  );

  /// The voice for the sound saved as [key]. Anything unrecognised — a sound
  /// from a newer build, a custom choice whose file is gone — falls back to
  /// the phone's own, so an alarm is never left with nothing to ring.
  factory AlarmVoice.of(String key, {String? customFile}) {
    if (key == kCustomSound && customFile != null && customFile.isNotEmpty) {
      return AlarmVoice(
        channel: 'timebox_alarm_${customFile.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}',
        label: 'Timebox alarms · your sound',
        uri: 'content://$kAndroidPackage.sounds/sounds/$customFile',
      );
    }
    for (final s in kAlarmSounds) {
      if (s.key == key) {
        return AlarmVoice(channel: 'timebox_alarm_$key', label: 'Timebox alarms · ${s.name}', resource: s.resource);
      }
    }
    return system;
  }

  Map<String, dynamic> toJson() => {'channel': channel, 'label': label, 'resource': resource, 'uri': uri};

  static AlarmVoice fromJson(Map<String, dynamic> j) => AlarmVoice(
        channel: j['channel'] as String,
        label: j['label'] as String,
        resource: j['resource'] as String?,
        uri: j['uri'] as String?,
      );
}

/// An alert on a block is stored as the sentence the editor shows for it.
const String kAtStart = 'At start of task';
const String kAtEnd = 'At end of task';

/// The sentence for an alert [before] minutes ahead of the start.
String alertLabel(int before) {
  if (before <= 0) return kAtStart;
  final h = before ~/ 60, m = before % 60;
  return '${h > 0 ? '${h}h' : ''}${h > 0 && m > 0 ? ' ' : ''}${m > 0 ? '${m}m' : ''} before start';
}

/// How an alert reads on screen. The stored sentences still say "task", from
/// before the timeline called its entries blocks.
String alertText(String alert) => switch (alert) {
      kAtStart => 'At the start',
      kAtEnd => 'At the end',
      _ => alert.replaceFirst(' before start', ' before'),
    };

/// Minutes ahead of the start that [alert] fires, or null for one that fires
/// at the end. Reads every label the app has ever written, old presets
/// included.
int? alertBefore(String alert) {
  if (alert == kAtEnd) return null;
  final m = RegExp(r'^(?:(\d+)h)? ?(?:(\d+)m)? before start$').firstMatch(alert);
  if (m == null) return 0;
  return (int.tryParse(m.group(1) ?? '') ?? 0) * 60 + (int.tryParse(m.group(2) ?? '') ?? 0);
}

/// When [alert] fires for a block starting at [start] and running [duration]
/// minutes, in minutes past midnight of the block's day. May be negative: an
/// hour before a 00:30 start falls on the evening before.
int alertTime(String alert, int start, int duration) {
  final before = alertBefore(alert);
  return before == null ? start + duration : start - before;
}

/// The nearest five minute mark.
int snapToStep(int minutes) => ((minutes + kStep ~/ 2) ~/ kStep) * kStep;

/// The next five minute mark at or after [minutes].
int snapUpToStep(int minutes) => ((minutes + kStep - 1) ~/ kStep) * kStep;

/// Separates a repeating block's id from the date it was cast onto.
const String kOccurrenceMark = '@';

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime keyToDate(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String todayKey() => dateKey(clock());

/// [d] moved by [n] calendar days. `d.add(Duration(days: n))` moves it by
/// n × 24 hours instead, and twice a year a day is 23 or 25 hours long: the
/// result is then an hour off, which is enough to land on the wrong date.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

/// The date [n] days from today as a key; negative for the past.
String dayKey(int n) => dateKey(addDays(clock(), n));

/// Whole calendar days from [a] to [b], whatever the hour on either. Counted
/// in UTC, where every day is the same length.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int nowMinutes() {
  final n = clock();
  return n.hour * 60 + n.minute;
}

String fmtMins(int mins, bool use24) {
  final v = ((mins % 1440) + 1440) % 1440;
  final h = v ~/ 60;
  final mm = (v % 60).toString().padLeft(2, '0');
  if (use24) return '${h.toString().padLeft(2, '0')}:$mm';
  final ap = h < 12 ? 'AM' : 'PM';
  var hh = h % 12;
  if (hh == 0) hh = 12;
  return '$hh:$mm $ap';
}

/// A span of time written the short way: "9:00 – 10:30 AM" rather than
/// saying AM twice, since a narrow card has no room to.
String fmtRange(int start, int end, bool use24) {
  final a = fmtMins(start, use24), b = fmtMins(end, use24);
  if (use24) return '$a – $b';
  final sameHalf = (start % 1440 < 720) == (end % 1440 < 720);
  return sameHalf ? '${a.substring(0, a.length - 3)} – $b' : '$a – $b';
}

String durLabel(int m) {
  if (m < 60) return '${m}m';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h${r}m';
}

class Block {
  String id;
  String date;
  String icon;
  String title;
  int start;
  int end;
  int color;
  String repeat;
  List<String> alerts;
  List<String> subtasks;

  /// Which of [alerts] ring like an alarm clock — loud, on the alarm volume,
  /// until stopped — rather than arriving as a quiet notification.
  List<String> rings;

  bool get alarm => rings.isNotEmpty;

  /// Dates this block repeats onto but should not appear on, because the user
  /// changed or removed that one occurrence.
  List<String> skips;

  Block({
    required this.id,
    required this.date,
    required this.icon,
    required this.title,
    required this.start,
    required this.end,
    this.color = 0,
    this.repeat = 'Once',
    List<String>? alerts,
    List<String>? subtasks,
    List<String>? skips,
    List<String>? rings,
  })  : alerts = alerts ?? <String>[],
        rings = rings ?? <String>[],
        subtasks = subtasks ?? <String>[],
        skips = skips ?? <String>[];

  int get duration => end - start;

  /// True for the copies a repeating block casts onto later days. They are
  /// built on the fly and are not in the stored list.
  bool get isOccurrence => id.contains(kOccurrenceMark);

  /// The id of the block a copy came from.
  String get seriesId => id.split(kOccurrenceMark).first;

  /// The copy this block casts onto [key].
  Block occurrenceOn(String key) => Block(
        id: '$id$kOccurrenceMark$key',
        date: key,
        icon: icon,
        title: title,
        start: start,
        end: end,
        color: color,
        repeat: repeat,
        alerts: List.of(alerts),
        subtasks: List.of(subtasks),
        rings: List.of(rings),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'icon': icon,
        'title': title,
        'start': start,
        'end': end,
        'color': color,
        'repeat': repeat,
        'alerts': alerts,
        'subtasks': subtasks,
        'skips': skips,
        'rings': rings,
      };

  static Block fromJson(Map<String, dynamic> j) => Block(
        id: j['id'] as String,
        date: j['date'] as String,
        icon: j['icon'] as String? ?? 'label',
        title: j['title'] as String? ?? '',
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        color: (j['color'] as num?)?.toInt() ?? 0,
        repeat: j['repeat'] as String? ?? 'Once',
        alerts: (j['alerts'] as List?)?.map((e) => e.toString()).toList(),
        subtasks: (j['subtasks'] as List?)?.map((e) => e.toString()).toList(),
        skips: (j['skips'] as List?)?.map((e) => e.toString()).toList(),
        // Build 32 had one switch for the whole block; it meant every alert.
        rings: (j['rings'] as List?)?.map((e) => e.toString()).toList() ??
            (j['alarm'] == true ? (j['alerts'] as List?)?.map((e) => e.toString()).toList() : null),
      );
}

/// An Inbox entry is a reusable template: adding it to a day does not consume it.
class InboxItem {
  String id;
  String icon;
  String title;
  int dur;

  /// The colour every block made from this entry starts with.
  int color;

  InboxItem({required this.id, required this.icon, required this.title, required this.dur, this.color = 0});

  Map<String, dynamic> toJson() => {'id': id, 'icon': icon, 'title': title, 'dur': dur, 'color': color};

  static InboxItem fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as String,
        icon: j['icon'] as String? ?? 'label',
        title: j['title'] as String? ?? '',
        dur: (j['dur'] as num?)?.toInt() ?? 30,
        color: (j['color'] as num?)?.toInt() ?? 0,
      );
}

class Task {
  String id;
  String title;

  /// Time of day the reminder fires, in minutes past midnight. Null for a task
  /// with no reminder.
  int? time;

  /// The day it is due, as a date key. Null means someday — the task sits at
  /// the bottom of the list and any reminder simply fires at the next [time].
  String? date;

  bool done;

  /// Ring as an alarm at [time] instead of sending a notification.
  bool alarm;

  Task({required this.id, required this.title, this.time, this.date, this.done = false, this.alarm = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'time': time, 'date': date, 'done': done, 'alarm': alarm};

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        time: (j['time'] as num?)?.toInt(),
        date: j['date'] as String?,
        done: j['done'] as bool? ?? false,
        alarm: j['alarm'] == true,
      );
}

/// One run of the task list under a heading.
class TaskSection {
  final String title;
  final List<Task> tasks;

  /// The day has gone by with these still open.
  final bool late;

  /// These are finished.
  final bool done;

  const TaskSection(this.title, this.tasks, {this.late = false, this.done = false});
}

/// The task list as it is read: what is overdue, then today, tomorrow and
/// later in the order they fall due, then the ones with no date in the order
/// they were written down, and what is finished last. Empty runs are left out.
List<TaskSection> taskSections(List<Task> tasks) {
  final open = tasks.where((t) => !t.done).toList();
  // Earliest day first, and within a day the earliest reminder; a task with
  // no time goes after those that have one.
  int byDue(Task a, Task b) {
    final day = a.date!.compareTo(b.date!);
    return day != 0 ? day : (a.time ?? 1440).compareTo(b.time ?? 1440);
  }

  List<Task> due(bool Function(int days) when) =>
      open.where((t) => t.date != null && when(daysUntil(t.date!))).toList()..sort(byDue);

  return [
    TaskSection('Overdue', due((d) => d < 0), late: true),
    TaskSection('Today', due((d) => d == 0)),
    TaskSection('Tomorrow', due((d) => d == 1)),
    TaskSection('Later', due((d) => d > 1)),
    TaskSection('Someday', open.where((t) => t.date == null).toList()),
    TaskSection('Done', tasks.where((t) => t.done).toList(), done: true),
  ].where((s) => s.tasks.isNotEmpty).toList();
}

class Habit {
  String id;
  String title;
  String icon;
  int? time;
  Map<String, bool> history;

  /// Ring as an alarm at [time] instead of sending a notification.
  bool alarm;

  /// Its place in the block palette, or null to wear the app's accent.
  int? color;

  Habit({
    required this.id,
    required this.title,
    this.icon = 'local_fire_department',
    this.time,
    Map<String, bool>? history,
    this.alarm = false,
    this.color,
  }) : history = history ?? <String, bool>{};

  bool doneOn(String key) => history[key] == true;

  /// Consecutive days ticked, counting back from today. A day that is not
  /// over yet cannot have broken anything, so until today is ticked the run
  /// that reached yesterday still stands.
  int get streak {
    var back = doneOn(dayKey(0)) ? 0 : 1;
    var n = 0;
    while (doneOn(dayKey(-back))) {
      n++;
      back++;
    }
    return n;
  }

  /// The longest run of consecutive days there has ever been.
  int get bestStreak {
    final days = history.keys.where(doneOn).map(keyToDate).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && daysBetween(prev, d) == 1 ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// How many days it has been ticked in all.
  int get total => history.keys.where(doneOn).length;

  /// How many of the [days] days ending today it was ticked on.
  int hitsIn(int days) {
    var n = 0;
    for (var i = 0; i < days; i++) {
      if (doneOn(dayKey(-i))) n++;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'time': time,
        'history': history,
        'alarm': alarm,
        'color': color,
      };

  static Habit fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        icon: j['icon'] as String? ?? 'local_fire_department',
        time: (j['time'] as num?)?.toInt(),
        history: (j['history'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)),
        alarm: j['alarm'] == true,
        color: (j['color'] as num?)?.toInt(),
      );
}

/// One row of the proportional timeline: where it sits and how tall it is.
class LaidOutBlock {
  final Block block;
  final double y;
  final double height;
  final bool overlaps;

  /// Which side-by-side slot this block sits in, and how many slots the run of
  /// overlapping blocks it belongs to was split into. Two things at once stand
  /// next to each other rather than pushing one another down the day.
  final int column;
  final int columns;

  LaidOutBlock({
    required this.block,
    required this.y,
    required this.height,
    required this.overlaps,
    this.column = 0,
    this.columns = 1,
  });
}

class TimelineLayout {
  final List<LaidOutBlock> rows;
  final double trackHeight;
  final int origin;
  final double ppm;
  final int first;
  final int last;

  /// Where [minutes] past midnight falls on the track. A short block is drawn
  /// taller than its time, which pushes everything after it down, so the
  /// answer has to come from where the blocks actually sit: inside a block it
  /// is that far through the card, and between two it is that far through the
  /// gap as drawn.
  double yOf(int minutes) {
    if (rows.isEmpty) return (minutes - origin) * ppm;
    LaidOutBlock? inside, before, after;
    for (final r in rows) {
      final b = r.block;
      if (b.start <= minutes && minutes < b.end) {
        // Of two blocks running side by side, follow the one that runs on
        // longest: the line then never has to jump back up when the shorter
        // one ends.
        if (inside == null || b.end > inside.block.end) inside = r;
      } else if (b.end <= minutes) {
        if (before == null || r.y + r.height > before.y + before.height) before = r;
      } else if (after == null || r.y < after.y) {
        after = r;
      }
    }
    if (inside != null) {
      return inside.y + (minutes - inside.block.start) / inside.block.duration * inside.height;
    }
    if (before == null) return after!.y - (after.block.start - minutes) * ppm;
    final bottom = before.y + before.height;
    if (after == null) return bottom + (minutes - before.block.end) * ppm;
    final gap = after.block.start - before.block.end;
    if (gap <= 0) return bottom;
    return bottom + (minutes - before.block.end) / gap * (after.y - bottom);
  }

  TimelineLayout({
    required this.rows,
    required this.trackHeight,
    required this.origin,
    required this.ppm,
    required this.first,
    required this.last,
  });
}

/// Whole days from today to [key]: 0 today, 1 tomorrow, negative once it has
/// gone by. Compared date to date, so the hour of day never tips the count.
int daysUntil(String key) {
  return daysBetween(clock(), keyToDate(key));
}

/// A due date in the words you would use out loud: the next few days by name,
/// anything further off as a date.
String dueLabel(String key) {
  final n = daysUntil(key);
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n == -1) return 'Yesterday';
  final d = keyToDate(key);
  if (n > 1 && n < 7) return weekdayName(d).substring(0, 3);
  final year = d.year == clock().year ? '' : ' ${d.year}';
  return '${d.day} ${monthShort(d.month)}$year';
}

String weekdayName(DateTime d) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return names[d.weekday - 1];
}

String monthName(int m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return names[m - 1];
}

String monthShort(int m) => monthName(m).substring(0, 3);

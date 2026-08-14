/// Plain data + the small helpers every screen shares.
library;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime keyToDate(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String todayKey() => dateKey(DateTime.now());

int nowMinutes() {
  final n = DateTime.now();
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
  })  : alerts = alerts ?? <String>[],
        subtasks = subtasks ?? <String>[];

  int get duration => end - start;

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
      );
}

/// An Inbox entry is a reusable template: adding it to a day does not consume it.
class InboxItem {
  String id;
  String icon;
  String title;
  int dur;

  InboxItem({required this.id, required this.icon, required this.title, required this.dur});

  Map<String, dynamic> toJson() => {'id': id, 'icon': icon, 'title': title, 'dur': dur};

  static InboxItem fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as String,
        icon: j['icon'] as String? ?? 'label',
        title: j['title'] as String? ?? '',
        dur: (j['dur'] as num?)?.toInt() ?? 30,
      );
}

class Task {
  String id;
  String title;
  int? time;
  bool done;

  Task({required this.id, required this.title, this.time, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'time': time, 'done': done};

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        time: (j['time'] as num?)?.toInt(),
        done: j['done'] as bool? ?? false,
      );
}

class Habit {
  String id;
  String title;
  String icon;
  int? time;
  Map<String, bool> history;

  Habit({
    required this.id,
    required this.title,
    this.icon = 'local_fire_department',
    this.time,
    Map<String, bool>? history,
  }) : history = history ?? <String, bool>{};

  bool doneOn(String key) => history[key] == true;

  /// Consecutive days ticked, counting back from today.
  int get streak {
    var n = 0;
    var d = DateTime.now();
    while (doneOn(dateKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'time': time,
        'history': history,
      };

  static Habit fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        icon: j['icon'] as String? ?? 'local_fire_department',
        time: (j['time'] as num?)?.toInt(),
        history: (j['history'] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)),
      );
}

/// One row of the proportional timeline: where it sits and how tall it is.
class LaidOutBlock {
  final Block block;
  final double y;
  final double height;
  final bool overlaps;

  LaidOutBlock({required this.block, required this.y, required this.height, required this.overlaps});
}

class TimelineLayout {
  final List<LaidOutBlock> rows;
  final double trackHeight;
  final int origin;
  final double ppm;
  final int first;
  final int last;

  TimelineLayout({
    required this.rows,
    required this.trackHeight,
    required this.origin,
    required this.ppm,
    required this.first,
    required this.last,
  });
}

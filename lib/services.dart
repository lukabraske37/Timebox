import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Real Android notifications: block alerts, task and habit reminders,
/// plus one optional daily summary.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // fall back to UTC if the platform channel is unavailable
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'timebox',
      'Timebox',
      channelDescription: 'Blocks, tasks and habits',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static tz.TZDateTime _next(String dayKey, int minutes) {
    final d = keyToDate(dayKey);
    var when = tz.TZDateTime(tz.local, d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  /// The exact moment [minutes] falls on [dayKey], or null if it has passed.
  /// Unlike [_next] this never rolls forward: a task due yesterday is late,
  /// not due again tomorrow.
  static tz.TZDateTime? _on(String dayKey, int minutes) {
    final d = keyToDate(dayKey);
    final when = tz.TZDateTime(tz.local, d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
    return when.isBefore(tz.TZDateTime.now(tz.local)) ? null : when;
  }

  static Future<void> _schedule(int id, String title, String body, tz.TZDateTime when) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels everything and re-schedules from current state. Cheap enough to
  /// call on every save, and it keeps notifications honest after any edit.
  static Future<void> sync({
    required List<Block> blocks,
    required List<Task> tasks,
    required List<Habit> habits,
    required bool blocksOn,
    required bool tasksOn,
    required bool habitsOn,
    required bool summaryOn,
    required int summaryTime,
    required bool use24,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    var id = 1;
    final today = todayKey();

    if (blocksOn) {
      for (final b in blocks) {
        if (b.date.compareTo(today) < 0) continue;
        for (final a in b.alerts) {
          final offset = switch (a) {
            'At start of task' => 0,
            'At end of task' => b.duration,
            '15m before start' => -15,
            '30m before start' => -30,
            '1h before start' => -60,
            _ => 0,
          };
          await _schedule(id++, b.title, '${fmtMins(b.start, use24)} – ${fmtMins(b.end, use24)}',
              _next(b.date, b.start + offset));
        }
      }
    }

    if (tasksOn) {
      for (final t in tasks) {
        if (t.done || t.time == null) continue;
        if (t.date == null) {
          await _schedule(id++, t.title, 'Task due', _next(today, t.time!));
        } else {
          final when = _on(t.date!, t.time!);
          if (when != null) await _schedule(id++, t.title, 'Due ${dueLabel(t.date!)}', when);
        }
      }
    }

    if (habitsOn) {
      for (final h in habits) {
        if (h.time == null) continue;
        await _plugin.zonedSchedule(
          id++,
          h.title,
          'Keep the streak going',
          _next(today, h.time!),
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }

    if (summaryOn) {
      await _plugin.zonedSchedule(
        id++,
        'Today in Timebox',
        'Tap to see how the day went',
        _next(today, summaryTime),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}

/// Fingerprint / face unlock on launch.
class Biometrics {
  static final _auth = LocalAuthentication();

  static Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Timebox',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Backup is one plain JSON file the user keeps themselves — nothing leaves
/// the phone unless they send it somewhere.
class Backup {
  static String get _name => 'timebox-backup-${todayKey()}.json';

  static String _encode(Map<String, dynamic> state) => const JsonEncoder.withIndent('  ')
      .convert({...state, 'app': 'timebox', 'exportedAt': DateTime.now().toIso8601String()});

  /// Lets the user choose where the file goes — Downloads, an SD card, or a
  /// Drive folder if they have one. Returns whether a file was written.
  static Future<bool> saveToDevice(Map<String, dynamic> state) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Timebox backup',
        fileName: _name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(_encode(state))),
      );
      return path != null;
    } catch (_) {
      return false;
    }
  }

  /// Hands the file to another app: mail, Drive, a chat with yourself.
  static Future<bool> share(Map<String, dynamic> state) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_name');
      await file.writeAsString(_encode(state));
      final result = await Share.shareXFiles([XFile(file.path)], subject: 'Timebox backup');
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }

  /// The picked file's contents, null if nothing was picked, or an error when
  /// the file is not something this app wrote.
  static Future<({Map<String, dynamic>? data, String? error})?> pick() async {
    final FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    } catch (_) {
      return (data: null, error: 'The file picker could not be opened.');
    }
    if (res == null || res.files.isEmpty) return null;
    final picked = res.files.single;
    try {
      final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      // A backup is a few hundred kilobytes at most; anything huge is the
      // wrong file, and reading it whole would only stall the app.
      if (bytes.length > 20 * 1024 * 1024) {
        return (data: null, error: 'That file is too large to be a Timebox backup.');
      }
      return parse(utf8.decode(bytes));
    } catch (_) {
      return (data: null, error: 'That file could not be read.');
    }
  }

  static ({Map<String, dynamic>? data, String? error}) parse(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic> && Store.looksLikeBackup(data)) return (data: data, error: null);
    } catch (_) {}
    return (data: null, error: 'That is not a Timebox backup file.');
  }
}

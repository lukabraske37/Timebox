import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

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
        await _schedule(id++, t.title, 'Task due', _next(today, t.time!));
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

/// Backup is one plain JSON file the user keeps themselves — nothing leaves the phone.
class Backup {
  static Future<void> export(Map<String, dynamic> state) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/timebox-backup-${todayKey()}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(state));
    await Share.shareXFiles([XFile(file.path)], subject: 'Timebox backup');
  }

  static Future<Map<String, dynamic>?> import() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null) return null;
    try {
      final text = await File(path).readAsString();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

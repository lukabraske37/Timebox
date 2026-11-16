import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// Runs when Stop or Snooze is pressed on an alarm. Android starts a fresh
/// isolate for it, so this works with the app closed and the phone locked —
/// which is exactly when an alarm gets answered.
@pragma('vm:entry-point')
Future<void> onAlarmAction(NotificationResponse response) async {
  if (response.actionId != Notifications.snoozeAction) return;
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.snooze(response.payload ?? 'Alarm');
}

/// What Android currently lets the app do, for the status rows in Settings.
class AlertStatus {
  final bool allowed;
  final bool exact;

  const AlertStatus(this.allowed, this.exact);
}

/// Real Android notifications and alarms: block alerts, task and habit
/// reminders, plus one optional daily summary.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const snoozeAction = 'snooze';
  static const _stopAction = 'stop';
  static const _snoozeKey = 'timebox.snoozes';

  /// Ids from here up belong to snoozed and test alarms, which [sync] leaves
  /// alone.
  static const _reservedFrom = 900000;
  static const _testId = 999999;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> _zones() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Left on UTC. Every time below is built from the phone's own clock and
      // then converted, so alerts still fire at the right moment.
    }
  }

  static Future<void> _start() => _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveBackgroundNotificationResponse: onAlarmAction,
      );

  /// Never throws: the app has to open whether or not Android lets it alert.
  /// What went wrong is kept in [lastError] for Settings to show.
  static Future<void> init() async {
    if (_ready) return;
    try {
      await _zones();
      await _start();
      _ready = true;
    } catch (e) {
      lastError = e.toString();
      return;
    }
    try {
      await _android?.requestNotificationsPermission();
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static Future<AlertStatus> status() async {
    try {
      return AlertStatus(
        await _android?.areNotificationsEnabled() ?? true,
        await _android?.canScheduleExactNotifications() ?? true,
      );
    } catch (_) {
      return const AlertStatus(true, true);
    }
  }

  /// Asks again for whatever [status] says is missing.
  static Future<void> requestAccess() async {
    try {
      await _android?.requestNotificationsPermission();
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// The sound alarms ring with. Set by the store before it schedules
  /// anything, and saved where the Snooze isolate can read it back.
  static AlarmVoice voice = AlarmVoice.system;
  static const _voiceKey = 'timebox.alarm_voice';

  static Future<void> useVoice(AlarmVoice next) async {
    if (next.channel == voice.channel) return;
    voice = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_voiceKey, jsonEncode(next.toJson()));
    } catch (_) {}
  }

  /// Drops the channels of sound files that have since been replaced. Android
  /// lists every channel an app has ever made, so they would pile up.
  static Future<void> forgetOldSounds() async {
    try {
      for (final ch in await _android?.getNotificationChannels() ?? const <AndroidNotificationChannel>[]) {
        if (ch.id.startsWith('timebox_alarm_custom') && ch.id != voice.channel) {
          await _android?.deleteNotificationChannel(ch.id);
        }
      }
    } catch (_) {}
  }

  /// An alarm, as opposed to a notification: its own channel on the alarm
  /// volume, so it sounds through silent mode the way the clock app's does,
  /// and a sound that keeps going until someone answers it.
  static NotificationDetails get _alarmDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          voice.channel,
          voice.label,
          channelDescription: 'Alarms that ring until you stop them',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: voice.resource != null
              ? RawResourceAndroidNotificationSound(voice.resource!) as AndroidNotificationSound
              : UriAndroidNotificationSound(voice.uri ?? AlarmVoice.system.uri!),
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 600, 400, 600, 400, 600]),
          // FLAG_INSISTENT: repeat the sound until the notification is answered.
          additionalFlags: Int32List.fromList([4]),
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          // Swiping it away by accident should not be the way an alarm ends.
          ongoing: true,
          autoCancel: true,
          // Nobody there to stop it: give up after ten minutes rather than
          // ringing an empty room all day.
          timeoutAfter: 10 * 60 * 1000,
          actions: const [
            AndroidNotificationAction(_stopAction, 'Stop', cancelNotification: true),
            AndroidNotificationAction(snoozeAction, 'Snooze $kSnoozeMinutes min', cancelNotification: true),
          ],
        ),
      );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'timebox',
      'Timebox',
      channelDescription: 'Blocks, tasks and habits',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// [minutes] past midnight on [dayKey] as a moment in time. Built from the
  /// phone's local clock and converted, so it is right even if the time zone
  /// lookup failed; [minutes] outside 0–1439 lands on the day before or after.
  static DateTime _moment(String dayKey, int minutes) {
    final d = keyToDate(dayKey);
    return DateTime(d.year, d.month, d.day, 0, minutes);
  }

  static tz.TZDateTime _tz(DateTime local) => tz.TZDateTime.from(local, tz.local);

  /// The next time the clock reads [minutes]: today if still ahead, otherwise
  /// tomorrow. For reminders that belong to a time of day, not to a date.
  static DateTime _nextAt(int minutes) {
    final when = _moment(todayKey(), minutes);
    return when.isAfter(DateTime.now()) ? when : _moment(dayKey(1), minutes);
  }

  /// Why the last attempt to schedule something failed, if it did. Shown in
  /// Settings: an alert that silently never fires is the worst kind.
  static String? lastError;

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when, {
    bool alarm = false,
    bool daily = false,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _tz(when),
        alarm ? _alarmDetails : _details,
        // An alarm goes through AlarmManager's alarm-clock path, which Android
        // will not defer for battery saving the way it may an ordinary one.
        androidScheduleMode: alarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: daily ? DateTimeComponents.time : null,
        payload: title,
      );
    } catch (_) {
      // Exact alarms can be switched off in system settings. A reminder a
      // few minutes late beats none, and one failure must not stop the rest.
      try {
        await _plugin.zonedSchedule(id, title, body, _tz(when), alarm ? _alarmDetails : _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: daily ? DateTimeComponents.time : null,
            payload: title);
      } catch (e) {
        lastError = e.toString();
      }
    }
  }

  // ---------- snooze ----------

  /// Snoozed alarms still to ring, from [raw] as stored, as of [now].
  static List<Map<String, dynamic>> pendingSnoozes(String? raw, DateTime now) {
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (DateTime.parse((e as Map)['at'] as String).isAfter(now)) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return [];
    }
  }

  /// [raw] with [title] snoozed from [now]. Pressing Snooze twice on the same
  /// alarm leaves one entry, not two.
  static String withSnooze(String? raw, String title, DateTime now) {
    final list = pendingSnoozes(raw, now)..removeWhere((e) => e['title'] == title);
    final used = {for (final e in list) e['id']};
    var id = _reservedFrom;
    while (used.contains(id)) {
      id++;
    }
    list.add({
      'id': id,
      'title': title,
      'at': now.add(const Duration(minutes: kSnoozeMinutes)).toIso8601String(),
    });
    return jsonEncode(list);
  }

  /// Rings [title] again in [kSnoozeMinutes]. Kept in its own stored list
  /// rather than in the app's state, because this runs in a separate isolate
  /// that must not write over what the app itself is saving.
  static Future<void> snooze(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = withSnooze(prefs.getString(_snoozeKey), title, DateTime.now());
    await prefs.setString(_snoozeKey, raw);
    // This isolate starts from nothing, so it has to be told which sound the
    // alarm it is putting off was ringing with.
    try {
      final saved = prefs.getString(_voiceKey);
      if (saved != null) voice = AlarmVoice.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {}
    await _zones();
    await _start();
    final mine = pendingSnoozes(raw, DateTime.now()).firstWhere((e) => e['title'] == title);
    await _schedule(mine['id'] as int, title, 'Snoozed', DateTime.parse(mine['at'] as String), alarm: true);
  }

  /// Rings in a few seconds, so the sound and the buttons can be tried
  /// without waiting for a real reminder.
  ///
  /// Returns what went wrong, or null if the alert is on its way.
  static Future<String?> test({required bool alarm, int seconds = 5}) async {
    try {
      await init();
      await _plugin.cancel(_testId);
    } catch (e) {
      return e.toString();
    }
    lastError = null;
    await _schedule(
      _testId,
      alarm ? 'Test alarm' : 'Test notification',
      alarm ? 'This is how an alarm rings' : 'This is how a notification arrives',
      DateTime.now().add(Duration(seconds: seconds)),
      alarm: alarm,
    );
    return lastError;
  }

  // ---------- sync ----------

  static Future<void>? _running;
  static Future<void> Function()? _waiting;

  /// Re-schedules everything from current state. Called on every save, so
  /// calls are run one at a time and only the newest waiting one is kept:
  /// two overlapping passes would cancel each other's work.
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
    Future<void> pass() => _sync(blocks, tasks, habits, blocksOn, tasksOn, habitsOn, summaryOn, summaryTime, use24);
    if (_running != null) {
      _waiting = pass;
      return;
    }
    _running = pass();
    try {
      await _running;
    } catch (_) {}
    _running = null;
    final next = _waiting;
    _waiting = null;
    if (next != null) {
      _running = next();
      try {
        await _running;
      } catch (_) {}
      _running = null;
    }
  }

  static Future<void> _sync(
    List<Block> blocks,
    List<Task> tasks,
    List<Habit> habits,
    bool blocksOn,
    bool tasksOn,
    bool habitsOn,
    bool summaryOn,
    int summaryTime,
    bool use24,
  ) async {
    // Only what is still waiting is cancelled. cancelAll would also silence
    // an alarm that is ringing right now, the moment anything was saved.
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (pending.id < _reservedFrom) await _plugin.cancel(pending.id);
    }
    var id = 1;
    final now = DateTime.now();

    if (blocksOn) {
      for (final b in blocks) {
        for (final a in b.alerts) {
          // An alert whose moment has gone is simply over. Rolling it to
          // tomorrow rang for a block that is not there tomorrow.
          final when = _moment(b.date, alertTime(a, b.start, b.duration));
          if (!when.isAfter(now)) continue;
          await _schedule(id++, b.title, '${fmtMins(b.start, use24)} – ${fmtMins(b.end, use24)}', when,
              alarm: b.rings.contains(a));
        }
      }
    }

    if (tasksOn) {
      for (final t in tasks) {
        if (t.done || t.time == null) continue;
        if (t.date == null) {
          await _schedule(id++, t.title, 'Task due', _nextAt(t.time!), alarm: t.alarm);
        } else {
          final when = _moment(t.date!, t.time!);
          if (when.isAfter(now)) {
            await _schedule(id++, t.title, 'Due ${dueLabel(t.date!)}', when, alarm: t.alarm);
          }
        }
      }
    }

    if (habitsOn) {
      for (final h in habits) {
        if (h.time == null) continue;
        await _schedule(id++, h.title, 'Keep the streak going', _nextAt(h.time!), alarm: h.alarm, daily: true);
      }
    }

    if (summaryOn) {
      await _schedule(id++, 'Today in Timebox', 'Tap to see how the day went', _nextAt(summaryTime), daily: true);
    }
  }
}

/// The alarm sounds: playing one as a preview, and taking in a file of the
/// user's own.
class Sounds {
  static AudioPlayer? _player;

  /// The key of the sound being previewed, for the row that shows a stop
  /// button instead of a play button.
  static final ValueNotifier<String?> playing = ValueNotifier(null);

  static Future<Directory> _folder() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/sounds');

  static Future<bool> has(String? file) async {
    if (file == null || file.isEmpty) return false;
    try {
      return await File('${(await _folder()).path}/$file').exists();
    } catch (_) {
      return false;
    }
  }

  /// Plays [key] once, or stops it if it is the one already playing.
  static Future<void> preview(String key, {String? customFile}) async {
    if (playing.value == key) return stop();
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      try {
        // As an alarm, so it comes out at the volume the alarm itself will.
        await player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ));
      } catch (_) {}
      await player.setReleaseMode(ReleaseMode.stop);
      playing.value = key;
      unawaited(player.onPlayerComplete.first.then((_) {
        if (playing.value == key) playing.value = null;
      }));
      if (key == kCustomSound) {
        await player.play(DeviceFileSource('${(await _folder()).path}/$customFile'));
      } else {
        final sound = kAlarmSounds.firstWhere((s) => s.key == key);
        await player.play(AssetSource(sound.asset));
      }
    } catch (_) {
      playing.value = null;
    }
  }

  static Future<void> stop() async {
    playing.value = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  /// What a picked file may be called once it is in the app's storage. The
  /// name ends up in an address Android reads, so nothing of the original
  /// name is kept but its extension.
  static String storedName(String original, int stamp) {
    final dot = original.lastIndexOf('.');
    final ext = dot < 0 ? '' : original.substring(dot + 1).toLowerCase();
    const known = ['mp3', 'ogg', 'oga', 'wav', 'm4a', 'aac', 'flac', 'opus', 'amr', 'mid', '3gp'];
    return 'custom_$stamp.${known.contains(ext) ? ext : 'mp3'}';
  }

  /// Lets the user pick an audio file and copies it into the app, replacing
  /// any they picked before. Null if they backed out.
  static Future<({String? file, String? name, String? error})?> pickCustom() async {
    final FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(type: FileType.audio);
    } catch (_) {
      return (file: null, name: null, error: 'The file picker could not be opened.');
    }
    if (res == null || res.files.isEmpty) return null;
    final picked = res.files.single;
    final path = picked.path;
    if (path == null) return (file: null, name: null, error: 'That file could not be read.');
    try {
      final source = File(path);
      // A song is a few megabytes. Anything far past that is a recording or a
      // video, and would be copied in full for nothing.
      if (await source.length() > 30 * 1024 * 1024) {
        return (file: null, name: null, error: 'That file is too large. Pick one under 30 MB.');
      }
      final folder = await _folder();
      await folder.create(recursive: true);
      final name = storedName(picked.name, DateTime.now().millisecondsSinceEpoch);
      await source.copy('${folder.path}/$name');
      await for (final old in folder.list()) {
        if (old is File && !old.path.endsWith('/$name')) {
          try {
            await old.delete();
          } catch (_) {}
        }
      }
      return (file: name, name: picked.name, error: null);
    } catch (_) {
      return (file: null, name: null, error: 'That file could not be copied into the app.');
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

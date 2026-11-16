import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/icons.dart';
import 'package:timebox/main.dart';
import 'package:timebox/models.dart';
import 'package:timebox/services.dart';
import 'package:timebox/store.dart';
import 'package:timebox/theme.dart';
import 'package:timebox/ui.dart';

/// Colours, icons, sounds and the habit numbers: the things this build added
/// or put right.
void main() {
  tearDown(() => clock = DateTime.now);

  test('every icon offered in the picker exists, and none a saved block uses was lost', () {
    for (final entry in kIconCategories.entries) {
      for (final name in entry.value) {
        expect(kIcons.containsKey(name), isTrue, reason: '${entry.key} offers "$name"');
      }
    }
    expect(kIcons.length, greaterThan(300));
    for (final old in ['directions_run', 'laptop_mac', 'groups', 'bedtime', 'local_fire_department', 'sunny']) {
      expect(kIcons.containsKey(old), isTrue, reason: '"$old" is in data saved by earlier builds');
    }
  });

  test('the two block palettes stay in step, and the first six never move', () {
    expect(kBlockColorsDark.length, kBlockColorsLight.length);
    expect(kBlockColorNames.length, kBlockColorsDark.length);
    expect(kBlockColorsDark.first, const Color(0xFF74EFD1), reason: 'saved blocks store a position in this list');
    expect(kBlockColorsDark[5], const Color(0xFF57C4D4));
  });

  test('text on a swatch is always readable', () {
    for (final fill in [...kBlockColorsDark, ...kBlockColorsLight]) {
      final on = AppColors.onColor(fill);
      final a = fill.computeLuminance(), b = on.computeLuminance();
      final contrast = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
      expect(contrast, greaterThan(4.0), reason: '$fill');
    }
  });

  test('every built-in alarm sound has its file, named so Android accepts it', () {
    for (final s in kAlarmSounds) {
      expect(File('assets/${s.asset}').existsSync(), isTrue, reason: s.asset);
      expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s.resource), isTrue, reason: s.resource);
    }
  });

  test('each sound rings on a channel of its own', () {
    final channels = {
      AlarmVoice.system.channel,
      for (final s in kAlarmSounds) AlarmVoice.of(s.key).channel,
      AlarmVoice.of(kCustomSound, customFile: 'custom_1.mp3').channel,
      AlarmVoice.of(kCustomSound, customFile: 'custom_2.mp3').channel,
    };
    expect(channels.length, kAlarmSounds.length + 3, reason: 'a channel keeps the sound it was made with');
    expect(AlarmVoice.of('classic').resource, 'alarm_classic');
    expect(AlarmVoice.of(kCustomSound, customFile: 'custom_1.mp3').uri,
        'content://com.timebox.timebox.sounds/sounds/custom_1.mp3');
    expect(AlarmVoice.of('gone-in-a-later-build').channel, AlarmVoice.system.channel);
    expect(AlarmVoice.of(kCustomSound).channel, AlarmVoice.system.channel, reason: 'no file, no custom sound');
    final v = AlarmVoice.of('bell');
    expect(AlarmVoice.fromJson(v.toJson()).channel, v.channel);
  });

  test('a picked file is stored under a name with nothing of the original but its type', () {
    expect(Sounds.storedName('My Song (live).MP3', 7), 'custom_7.mp3');
    expect(Sounds.storedName('../../evil', 7), 'custom_7.mp3');
    expect(Sounds.storedName('tone.ogg', 7), 'custom_7.ogg');
  });

  test('a restore does not bring a sound file from another phone with it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = Store(notifications: false);
    await store.load();
    addTearDown(store.dispose);
    final backup = store.toJson()
      ..['alarmSound'] = kCustomSound
      ..['customSoundFile'] = 'custom_9.mp3';
    await store.restore(backup);
    expect(store.alarmSound, kSystemSound);
    expect(store.alarmVoice.channel, AlarmVoice.system.channel);

    await store.restore(store.toJson()..['alarmSound'] = 'harp');
    expect(store.alarmSoundName, 'Harp', reason: 'a built-in sound travels fine');
  });

  test('a streak stands until the day is over, and the best run is remembered', () {
    clock = () => DateTime(2026, 11, 16, 9);
    final h = Habit(id: 'h', title: 'Read', history: {
      for (final d in ['01', '02', '03', '04', '05']) '2026-11-$d': true,
      '2026-11-14': true,
      '2026-11-15': true,
    });
    expect(h.streak, 2, reason: 'today is not ticked yet, but it is not over either');
    h.history['2026-11-16'] = true;
    expect(h.streak, 3);
    expect(h.bestStreak, 5);
    expect(h.total, 8);
    expect(h.hitsIn(7), 3);
    clock = () => DateTime(2026, 11, 18, 9);
    expect(h.streak, 0, reason: 'a whole day missed ends it');
  });

  test('choosing a day moves the week strip with it', () {
    clock = () => DateTime(2026, 11, 16, 9); // a Monday
    final store = Store(notifications: false);
    addTearDown(store.dispose);
    store.selectDay(DateTime(2026, 11, 22));
    expect(store.weekOffset, 0);
    store.selectDay(DateTime(2026, 11, 23));
    expect(store.weekOffset, 1);
    expect(store.weekDays.map(dateKey), contains('2026-11-23'));
    store.selectDay(DateTime(2026, 11, 15));
    expect(store.weekOffset, -1);
    store.selectDay(clock());
    expect(store.weekOffset, 0);
    expect(store.selectedIsToday, isTrue);
  });

  test('a span of time says AM or PM once when once is enough', () {
    expect(fmtRange(540, 630, false), '9:00 – 10:30 AM');
    expect(fmtRange(690, 765, false), '11:30 AM – 12:45 PM');
    expect(fmtRange(540, 630, true), '09:00 – 10:30');
  });

  testWidgets('a colour picked for an existing block is applied at once, and the editor wears it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_timeline).last);
    await tester.pumpAndSettle();
    final store = AppScope.of(tester.element(find.byType(Scaffold).first));
    final block = store.blocks.firstWhere((b) => b.title == 'Deep work: pricing page');
    expect(block.color, 0);

    await tester.tap(find.text(block.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('color-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-7')));
    await tester.pumpAndSettle();

    expect(store.blocks.firstWhere((b) => b.id == block.id).color, 7,
        reason: 'saved without Save: closing the sheet must not throw the colour away');
    final button = tester.widget<Material>(
        find.ancestor(of: find.text('Save Changes'), matching: find.byType(Material)).first);
    expect(button.color, kBlockColorsDark[7], reason: 'the whole sheet takes the colour, not one tile');
  });

  testWidgets('a flick across the timeline moves to the next day', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 3200);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TimeboxApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.view_timeline).last);
    await tester.pumpAndSettle();
    final store = AppScope.of(tester.element(find.byType(Scaffold).first));
    final today = store.selectedKey;

    await tester.fling(find.text('Morning run'), const Offset(-250, 0), 1200);
    await tester.pumpAndSettle();
    expect(store.selectedKey, dayKey(1));
    expect(find.byKey(const ValueKey('go-today')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('go-today')));
    await tester.pumpAndSettle();
    expect(store.selectedKey, today);

    // Scrolling the day up and down must not be mistaken for it.
    await tester.drag(find.text('Morning run'), const Offset(12, -200));
    await tester.pumpAndSettle();
    expect(store.selectedKey, today);
  });

  for (final wanted in [true, false]) {
    testWidgets('a new block ${wanted ? 'starts with an alert' : 'starts with none when that is switched off'}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const TimeboxApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.view_timeline).last);
      await tester.pumpAndSettle();
      final store = AppScope.of(tester.element(find.byType(Scaffold).first));
      store.mutate(() => store.alertNewBlocks = wanted);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Brand new');
      await tester.pump(const Duration(seconds: 25)); // long enough for the clock to tick under the sheet
      await tester.tap(find.text('Create Block'));
      await tester.pumpAndSettle();

      final made = store.blocks.firstWhere((b) => b.title == 'Brand new');
      expect(made.alerts, wanted ? [kAtStart] : isEmpty);
    });
  }
}

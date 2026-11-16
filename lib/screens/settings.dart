import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final channels = (store.notifBlocks ? 1 : 0) + (store.notifTasks ? 1 : 0) + (store.notifHabits ? 1 : 0);

    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Column(children: [
      ScreenTitle(title: 'Settings', subtitle: 'Timebox $kAppVersion · local only'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
          children: [
            // A backup that is weeks old, or was never made, is said here
            // rather than left to be found two screens down.
            if (store.daysSinceBackup == null || store.daysSinceBackup! >= 14) ...[
              Panel(
                key: const ValueKey('backup-nudge'),
                color: washOf(c, c.danger),
                onTap: () => open(const BackupPage()),
                child: Row(children: [
                  Icon(Icons.cloud_off, size: 21, color: c.danger),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        store.daysSinceBackup == null
                            ? 'No backup yet'
                            : 'Last backup ${store.daysSinceBackup} days ago',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt),
                      ),
                      const SizedBox(height: 3),
                      Text('Your plans live only on this phone. Save a copy.',
                          style: TextStyle(fontSize: 12, color: c.txt2)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: c.txt3),
                ]),
              ),
              const SizedBox(height: 22),
            ],
            const SectionLabel('Appearance'),
            NavRow(
              icon: Icons.palette,
              title: 'Theme and accent',
              subtitle: '${kThemeLabels[store.theme] ?? 'Dark'} · ${store.accent}',
              onTap: () => open(const LookPage()),
            ),
            const SizedBox(height: 10),
            SwitchRow(
              title: 'Colours for blocks and habits',
              subtitle: 'Off tints everything with the accent',
              value: store.blockColorIcons,
              onChanged: (v) => store.mutate(() => store.blockColorIcons = v),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Timeline'),
            NavRow(
              icon: Icons.add_box,
              title: 'New blocks',
              subtitle: store.defaultsSummary,
              onTap: () => open(const DefaultsPage()),
            ),
            const SizedBox(height: 10),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.view_timeline, size: 19, color: c.acc),
                  const SizedBox(width: 10),
                  Text('Layout', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
                ]),
                const SizedBox(height: 14),
                Segmented<bool>(
                  values: const [false, true],
                  labels: const ['Proportional', 'Classic list'],
                  value: store.classicTimeline,
                  onChanged: (v) => store.mutate(() => store.classicTimeline = v),
                ),
                const SizedBox(height: 10),
                Text(
                  store.classicTimeline
                      ? 'Blocks sit in an even list. Gaps between them are not to scale.'
                      : 'Empty time takes up real height, so a three-hour gap looks like three hours.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: c.txt3),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: store.classicTimeline ? 0.45 : 1,
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.height, size: 19, color: c.acc),
                    const SizedBox(width: 10),
                    Text('Hours on screen',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
                  ]),
                  const SizedBox(height: 14),
                  Segmented<String>(
                    values: const ['compact', 'normal', 'roomy'],
                    labels: const ['More', 'Normal', 'Fewer'],
                    value: store.zoom,
                    onChanged: (v) => store.mutate(() {
                      store.zoom = v;
                      store.classicTimeline = false;
                    }),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Alerts'),
            NavRow(
              icon: Icons.notifications,
              title: 'Notifications & Alerts',
              subtitle: '$channels of 3 channels on',
              onTap: () => open(const NotificationsPage()),
            ),
            const SizedBox(height: 10),
            NavRow(
              icon: Icons.music_note,
              title: 'Alarm sound',
              subtitle: store.alarmSoundName,
              onTap: () => open(const AlarmSoundPage()),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Your data'),
            NavRow(
              icon: Icons.save_alt,
              title: 'Backup',
              subtitle: store.daysSinceBackup == null
                  ? 'No backup file yet'
                  : store.daysSinceBackup == 0
                      ? 'Backed up today'
                      : 'Last backup ${store.daysSinceBackup} days ago',
              onTap: () => open(const BackupPage()),
            ),
            const SizedBox(height: 10),
            NavRow(
              icon: Icons.fingerprint,
              title: 'App Lock',
              subtitle: store.biometric ? 'On · locks when you leave' : 'Off',
              onTap: () => open(const LockPage()),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Preferences'),
            SwitchRow(
              title: 'Use 24 hr clock',
              subtitle: 'Show times as 14:30',
              value: store.use24,
              onChanged: (v) => store.mutate(() => store.use24 = v),
            ),
            const SizedBox(height: 10),
            SwitchRow(
              title: 'Start weeks from Sundays',
              subtitle: 'Week strip begins on Sunday',
              value: store.sundayFirst,
              onChanged: (v) => store.mutate(() => store.sundayFirst = v),
            ),
            const SizedBox(height: 10),
            SwitchRow(
              title: 'Show habits page first',
              subtitle: 'Open Habits at startup',
              value: store.habitsFirst,
              onChanged: (v) => store.mutate(() => store.habitsFirst = v),
            ),
            const SizedBox(height: 22),
            const SectionLabel('About'),
            NavRow(
              icon: Icons.info,
              title: 'About',
              subtitle: 'Timebox $kAppVersion',
              onTap: () => open(const AboutPage()),
            ),
          ],
        ),
      ),
    ]);
  }
}

class SubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SubPage({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 18, 4),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.txt)),
              Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.txt)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 30), children: children),
          ),
        ]),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    return SubPage(title: 'Notifications & Alerts', children: [
      const AlertCheck(),
      const SizedBox(height: 22),
      const SectionLabel('Alarms'),
      NavRow(
        icon: Icons.music_note,
        title: 'Alarm sound',
        subtitle: store.alarmSoundName,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlarmSoundPage())),
      ),
      const SizedBox(height: 22),
      const SectionLabel('What may alert you'),
      SwitchRow(
        title: 'Timeline blocks',
        subtitle: 'Alerts you set on a block',
        value: store.notifBlocks,
        onChanged: (v) => store.mutate(() => store.notifBlocks = v),
      ),
      const SizedBox(height: 10),
      SwitchRow(
        title: 'Task reminders',
        subtitle: 'One notification at the task time',
        value: store.notifTasks,
        onChanged: (v) => store.mutate(() => store.notifTasks = v),
      ),
      const SizedBox(height: 10),
      SwitchRow(
        title: 'Habit reminders',
        subtitle: 'Nudge on days you have not ticked yet',
        value: store.notifHabits,
        onChanged: (v) => store.mutate(() => store.notifHabits = v),
      ),
      const SizedBox(height: 10),
      SwitchRow(
        title: 'Daily summary',
        subtitle: 'One recap of the day',
        value: store.dailySummary,
        onChanged: (v) => store.mutate(() => store.dailySummary = v),
      ),
      if (store.dailySummary) ...[
        const SizedBox(height: 10),
        Panel(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Summary at', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
                Text('Steps of 30 minutes', style: TextStyle(fontSize: 12, color: c.txt3)),
              ]),
            ),
            _round(c, Icons.remove, () => store.mutate(() => store.summaryTime = (store.summaryTime + 1410) % 1440)),
            SizedBox(
              width: 84,
              child: Text(fmtMins(store.summaryTime, store.use24),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.txt)),
            ),
            _round(c, Icons.add, () => store.mutate(() => store.summaryTime = (store.summaryTime + 30) % 1440)),
          ]),
        ),
      ],
    ]);
  }

  Widget _round(AppColors c, IconData icon, VoidCallback onTap) => Material(
        color: c.surf2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 19, color: c.txt2)),
        ),
      );
}

/// Says whether Android will actually deliver alerts, and lets one be tried
/// on the spot instead of waiting for a real reminder to find out.
class AlertCheck extends StatefulWidget {
  const AlertCheck({super.key});

  @override
  State<AlertCheck> createState() => _AlertCheckState();
}

class _AlertCheckState extends State<AlertCheck> with WidgetsBindingObserver {
  AlertStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The permission is changed in system settings, so look again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await Notifications.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _try(bool alarm) async {
    final error = await Notifications.test(alarm: alarm);
    if (!mounted) return;
    setState(() {});
    if (error != null) {
      showNotice(context, 'Could not be scheduled — see the reason above', bad: true);
    } else {
      showNotice(context, alarm ? 'Alarm rings in 5 seconds — lock the phone to try it there' : 'Notification in 5 seconds');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final status = _status;
    final problem = status == null
        ? null
        : !status.allowed
            ? 'Notifications are switched off for Timebox, so nothing can alert you.'
            : !status.exact
                ? 'Exact timing is not allowed, so alerts and alarms can arrive minutes late.'
                : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (problem != null) ...[
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline, size: 20, color: c.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(problem,
                    style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600, color: c.txt)),
              ),
            ]),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Allow',
              onTap: () async {
                await Notifications.requestAccess();
                await _refresh();
              },
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ] else if (status != null) ...[
        Panel(
          child: Row(children: [
            Icon(Icons.check_circle, size: 20, color: c.acc),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Alerts are allowed and fire on the minute.',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.txt)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      if (Notifications.lastError != null) ...[
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The last alert could not be scheduled',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.danger)),
            const SizedBox(height: 6),
            SelectableText(Notifications.lastError!,
                maxLines: 6, style: TextStyle(fontSize: 12, height: 1.4, color: c.txt2)),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      Row(children: [
        Expanded(
          child: PrimaryButton(
            label: 'Test notification',
            background: c.surf2,
            foreground: c.txt,
            onTap: () => _try(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryButton(label: 'Test alarm', icon: Icons.alarm, onTap: () => _try(true)),
        ),
      ]),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'If a test never arrives, the phone is holding Timebox back: open its system settings and '
          'set Battery to Unrestricted. Xiaomi, Huawei, Oppo and Samsung phones do this most.',
          style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3),
        ),
      ),
    ]);
  }
}

/// Where the sound an alarm rings with is chosen: the phone's own, one of
/// the sounds that come with the app, or a file from the phone.
class AlarmSoundPage extends StatefulWidget {
  const AlarmSoundPage({super.key});

  @override
  State<AlarmSoundPage> createState() => _AlarmSoundPageState();
}

class _AlarmSoundPageState extends State<AlarmSoundPage> {
  @override
  void dispose() {
    // A preview must not carry on playing over whatever comes next.
    Sounds.stop();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final store = AppScope.of(context);
    await Sounds.stop();
    final picked = await Sounds.pickCustom();
    if (picked == null || !mounted) return;
    if (picked.file == null) {
      showNotice(context, picked.error ?? 'That file could not be used.', bad: true);
      return;
    }
    store.setCustomSound(picked.file!, picked.name ?? 'Your sound');
    showNotice(context, 'Alarms now ring with your sound');
  }

  Future<void> _ringTest() async {
    await Sounds.stop();
    final error = await Notifications.test(alarm: true);
    if (!mounted) return;
    showNotice(
      context,
      error == null ? 'Alarm rings in 5 seconds' : 'The test alarm could not be set',
      bad: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final hasCustom = store.customSoundFile != null;

    return SubPage(title: 'Alarm sound', children: [
      _SoundRow(
        soundKey: kSystemSound,
        name: 'Phone alarm',
        about: "Your phone's own alarm sound",
        selected: store.alarmSound == kSystemSound,
        onSelect: () {
          Sounds.stop();
          store.setAlarmSound(kSystemSound);
        },
      ),
      const SizedBox(height: 22),
      const SectionLabel('Timebox sounds'),
      for (final sound in kAlarmSounds) ...[
        _SoundRow(
          soundKey: sound.key,
          name: sound.name,
          about: sound.about,
          selected: store.alarmSound == sound.key,
          // Choosing a sound plays it: hearing it is the point of choosing.
          onSelect: () {
            store.setAlarmSound(sound.key);
            if (Sounds.playing.value != sound.key) Sounds.preview(sound.key);
          },
          onPreview: () => Sounds.preview(sound.key),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 14),
      const SectionLabel('Your own'),
      if (hasCustom) ...[
        _SoundRow(
          soundKey: kCustomSound,
          name: store.customSoundName ?? 'Your sound',
          about: 'A file from this phone',
          selected: store.alarmSound == kCustomSound,
          onSelect: () {
            store.setAlarmSound(kCustomSound);
            if (Sounds.playing.value != kCustomSound) {
              Sounds.preview(kCustomSound, customFile: store.customSoundFile);
            }
          },
          onPreview: () => Sounds.preview(kCustomSound, customFile: store.customSoundFile),
        ),
        const SizedBox(height: 8),
      ],
      PrimaryButton(
        label: hasCustom ? 'Choose a different file' : 'Choose a sound file',
        icon: Icons.audio_file,
        background: c.surf2,
        foreground: c.txt,
        onTap: _pickFile,
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Any song or recording on the phone. Timebox keeps its own copy, so the alarm still rings '
          'if the original is moved or deleted.',
          style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3),
        ),
      ),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Ring a test alarm', icon: Icons.alarm, onTap: _ringTest),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'The preview plays through the app. The test rings the way a real alarm will — on the alarm '
          'volume, until you stop it — so it is the one to trust.',
          style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3),
        ),
      ),
    ]);
  }
}

class _SoundRow extends StatelessWidget {
  final String soundKey;
  final String name;
  final String about;
  final bool selected;
  final VoidCallback onSelect;

  /// Null for a sound the app cannot play itself, such as the phone's own.
  final VoidCallback? onPreview;

  const _SoundRow({
    required this.soundKey,
    required this.name,
    required this.about,
    required this.selected,
    required this.onSelect,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Panel(
      key: ValueKey('sound-$soundKey'),
      color: selected ? washOf(c, c.acc) : c.surf,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      onTap: onSelect,
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? c.acc : Colors.transparent,
            border: Border.all(color: selected ? c.acc : c.txt3, width: 2),
          ),
          child: selected ? Icon(Icons.check, size: 14, color: c.accTxt) : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
              const SizedBox(height: 3),
              Text(about, style: TextStyle(fontSize: 12, color: c.txt3)),
            ]),
          ),
        ),
        if (onPreview != null)
          ValueListenableBuilder<String?>(
            valueListenable: Sounds.playing,
            builder: (_, playing, __) => IconButton(
              tooltip: playing == soundKey ? 'Stop' : 'Play',
              onPressed: onPreview,
              icon: Icon(playing == soundKey ? Icons.stop_circle : Icons.play_circle,
                  size: 30, color: playing == soundKey ? c.acc : c.txt2),
            ),
          )
        else
          const SizedBox(height: 48),
      ]),
    );
  }
}

/// What a new block starts out as. Everything here can still be changed in
/// the block's own editor; this only decides where it begins.
class DefaultsPage extends StatelessWidget {
  const DefaultsPage({super.key});

  static const _before = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final alert = store.defaultAlert;
    final before = alert == null ? null : alertBefore(alert);
    // 'none', 'start', 'before' or 'end'.
    final when = alert == null
        ? 'none'
        : before == null
            ? 'end'
            : (before == 0 ? 'start' : 'before');

    return SubPage(title: 'New blocks', children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        child: Text('How a block starts out when you make one. Each block can still be changed in its own editor.',
            style: TextStyle(fontSize: 13, height: 1.5, color: c.txt2)),
      ),
      const SectionLabel('Alert'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Segmented<String>(
            values: const ['none', 'start', 'before', 'end'],
            labels: const ['None', 'At start', 'Before', 'At end'],
            value: when,
            onChanged: (v) => store.mutate(() {
              store.defaultAlert = switch (v) {
                'start' => kAtStart,
                'end' => kAtEnd,
                'before' => alertLabel(before != null && before > 0 ? before : 10),
                _ => null,
              };
              if (v == 'none') store.defaultAlertRings = false;
            }),
          ),
          if (when == 'before') ...[
            const SizedBox(height: 12),
            Row(children: [
              for (final m in _before) ...[
                if (m != _before.first) const SizedBox(width: 6),
                Expanded(
                  child: PillButton(
                    label: durLabel(m),
                    height: 38,
                    selected: before == m,
                    onTap: () => store.mutate(() => store.defaultAlert = alertLabel(m)),
                  ),
                ),
              ],
            ]),
          ],
          const SizedBox(height: 12),
          if (when == 'none')
            Text('A new block has no alert until you add one.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: c.txt3))
          else
            AlarmChoice(
              alarm: store.defaultAlertRings,
              onChanged: (v) => store.mutate(() => store.defaultAlertRings = v),
            ),
        ]),
      ),
      const SizedBox(height: 22),
      const SectionLabel('Length'),
      Panel(
        child: Row(children: [
          for (final m in kDurations) ...[
            if (m != kDurations.first) const SizedBox(width: 6),
            Expanded(
              child: PillButton(
                label: durLabel(m),
                height: 40,
                selected: store.defaultDuration == m,
                onTap: () => store.mutate(() => store.defaultDuration = m),
              ),
            ),
          ],
        ]),
      ),
      if (store.blockColorIcons) ...[
        const SizedBox(height: 22),
        const SectionLabel('Colour'),
        Panel(
          child: ColorRow(
            value: store.defaultColor,
            onChanged: (v) => store.mutate(() => store.defaultColor = v ?? 0),
          ),
        ),
      ],
    ]);
  }
}

class LookPage extends StatelessWidget {
  const LookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    return SubPage(title: 'Look and Feel', children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Theme', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: [
              for (final name in kThemeNames)
                GestureDetector(
                  onTap: () => store.mutate(() => store.theme = name),
                  child: Container(
                    decoration: BoxDecoration(
                      color: store.theme == name ? c.accTint : c.surf2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: store.theme == name ? c.acc : c.line, width: store.theme == name ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.resolve(name, store.accent).surf,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.withOpacity(0.35)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(kThemeLabels[name]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: store.theme == name ? c.acc : c.txt2,
                          )),
                    ]),
                  ),
                ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Accent', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final name in kAccentNames)
              Semantics(
                button: true,
                selected: store.accent == name,
                label: name,
                child: GestureDetector(
                  key: ValueKey('accent-$name'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => store.mutate(() => store.accent = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 40,
                    height: 40,
                    padding: EdgeInsets.all(store.accent == name ? 4 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: store.accent == name
                          ? Border.all(color: AppColors.accentSwatch(name), width: 2.5)
                          : null,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.accentSwatch(name), shape: BoxShape.circle),
                      child: store.accent == name
                          ? Icon(Icons.check, size: 17, color: AppColors.onColor(AppColors.accentSwatch(name)))
                          : null,
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Accent drives buttons, the now line and every highlight. Block colors stay their own.',
              style: TextStyle(fontSize: 12, height: 1.45, color: c.txt3)),
        ]),
      ),
    ]);
  }
}

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  static String snapshotLabel(Snapshot s) {
    if (s.isBeforeRestore) return 'Before the last restore';
    final n = daysUntil(s.id);
    if (n == 0) return 'Start of today';
    if (n == -1) return 'Yesterday';
    final d = keyToDate(s.id);
    return '${weekdayName(d)} ${d.day} ${monthShort(d.month)}';
  }

  static String _counts(int blocks, int tasks, int habits, int inbox) =>
      '$blocks blocks · $tasks tasks · $habits habits · $inbox inbox';

  Future<void> _restoreFile(BuildContext context) async {
    final store = AppScope.of(context);
    final picked = await Backup.pick();
    if (picked == null || !context.mounted) return;
    final data = picked.data;
    if (data == null) {
      showNotice(context, picked.error ?? 'That file could not be read.', bad: true);
      return;
    }
    final n = Store.countsIn(data);
    final ok = await confirm(
      context,
      title: 'Restore this backup?',
      body: 'It holds ${_counts(n.blocks, n.tasks, n.habits, n.inbox)}.\n\n'
          'Everything in the app now is replaced. A copy of it is kept under '
          '"Earlier copies" in case this is the wrong file.',
      action: 'Restore',
    );
    if (!ok || !context.mounted) return;
    final done = await store.restore(data);
    if (context.mounted) showNotice(context, done ? 'Backup restored' : 'That backup could not be restored', bad: !done);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final since = store.daysSinceBackup;
    final stale = since == null || since >= 14;
    final snaps = store.snapshots();

    return SubPage(title: 'Backup', children: [
      Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: stale ? c.danger.withOpacity(c.isDark ? 0.18 : 0.10) : c.accTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(stale ? Icons.cloud_off : Icons.verified_user, size: 21, color: stale ? c.danger : c.acc),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                since == null
                    ? 'No backup file yet'
                    : since == 0
                        ? 'Backed up today'
                        : 'Last backup $since ${since == 1 ? 'day' : 'days'} ago',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.txt),
              ),
              const SizedBox(height: 4),
              Text(
                _counts(store.blocks.length, store.tasks.length, store.habits.length, store.inbox.length),
                style: TextStyle(fontSize: 12.5, height: 1.5, color: c.txt2),
              ),
              if (stale) ...[
                const SizedBox(height: 6),
                Text('Your plans live only on this phone. Save a file somewhere else so a lost or reset phone does not take them with it.',
                    style: TextStyle(fontSize: 12, height: 1.45, color: c.txt3)),
              ],
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      PrimaryButton(
        label: 'Save a backup file',
        icon: Icons.save_alt,
        onTap: () async {
          final saved = await Backup.saveToDevice(store.toJson());
          if (saved) store.markBackedUp();
          if (context.mounted && saved) showNotice(context, 'Backup saved');
        },
      ),
      const SizedBox(height: 10),
      PrimaryButton(
        label: 'Send a backup to another app',
        icon: Icons.ios_share,
        background: c.surf2,
        foreground: c.txt,
        onTap: () async {
          if (await Backup.share(store.toJson())) store.markBackedUp();
        },
      ),
      const SizedBox(height: 10),
      PrimaryButton(
        label: 'Restore from a file',
        icon: Icons.upload,
        background: c.surf2,
        foreground: c.txt,
        onTap: () => _restoreFile(context),
      ),
      const SizedBox(height: 24),
      const SectionLabel('Earlier copies'),
      if (snaps.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Timebox keeps a copy from each of the last $kSnapshotsKept days you opened it. The first one appears tomorrow.',
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.txt3)),
        )
      else ...[
        for (final snap in snaps) ...[
          NavRow(
            icon: snap.isBeforeRestore ? Icons.undo : Icons.history,
            title: snapshotLabel(snap),
            subtitle: _counts(snap.blocks, snap.tasks, snap.habits, snap.inbox),
            onTap: () async {
              final ok = await confirm(
                context,
                title: 'Go back to this copy?',
                body: '${snapshotLabel(snap)}: ${_counts(snap.blocks, snap.tasks, snap.habits, snap.inbox)}.\n\n'
                    'What is in the app now is kept as "Before the last restore".',
                action: 'Go back',
              );
              if (!ok || !context.mounted) return;
              final done = await store.restoreSnapshot(snap.id);
              if (context.mounted) showNotice(context, done ? 'Copy restored' : 'That copy could not be read', bad: !done);
            },
          ),
          const SizedBox(height: 10),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Kept automatically on this phone for $kSnapshotsKept days. They go if the app is uninstalled — a backup file does not.',
              style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3)),
        ),
      ],
      const SizedBox(height: 24),
      const SectionLabel('Danger zone'),
      DangerRow(
        icon: Icons.delete_forever,
        label: 'Erase everything',
        onTap: () async {
          final ok = await confirm(
            context,
            title: 'Erase everything?',
            body: 'All blocks, tasks, habits and inbox entries are removed. Settings stay. '
                'A copy is kept under "Earlier copies" until the next restore.',
            action: 'Erase',
            danger: true,
          );
          if (!ok) return;
          await store.eraseAll();
          if (context.mounted) showNotice(context, 'Everything erased');
        },
      ),
    ]);
  }
}

class LockPage extends StatelessWidget {
  const LockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    return SubPage(title: 'App Lock', children: [
      SwitchRow(
        title: 'Require unlock',
        subtitle: 'Fingerprint, face or your screen lock',
        value: store.biometric,
        onChanged: (v) async {
          if (v && !await Biometrics.available()) {
            if (context.mounted) {
              showNotice(context, 'Set up a fingerprint or screen lock on this phone first', bad: true);
            }
            return;
          }
          // Turning the lock off is exactly what someone holding an unlocked
          // phone would try, so both directions ask for the owner.
          if (!await Biometrics.authenticate()) return;
          store.mutate(() => store.biometric = v);
        },
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Timebox locks when it is opened and again after ${Store.lockAfter.inSeconds} seconds in the background. '
          'While the lock is on, the app is blanked out in the recent-apps view.',
          style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3),
        ),
      ),
      if (store.biometric) ...[
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Lock now',
          icon: Icons.lock,
          background: c.surf2,
          foreground: c.txt,
          onTap: () {
            store.mutate(() => store.locked = true);
            Navigator.pop(context);
          },
        ),
      ],
    ]);
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return SubPage(title: 'About', children: [
      Panel(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.schedule, size: 32, color: c.acc),
          ),
          const SizedBox(height: 14),
          Text('Timebox $kAppVersion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.txt)),
          const SizedBox(height: 6),
          Text('Local-only day planner. No account, no cloud, no analytics.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: c.txt2)),
        ]),
      ),
      const SizedBox(height: 10),
      Panel(
        child: Column(children: [
          _row(c, 'Build', kAppBuild),
          const SizedBox(height: 12),
          _row(c, 'Storage', 'On this phone only'),
          const SizedBox(height: 12),
          _row(c, 'Network', 'Never used'),
          const SizedBox(height: 12),
          _row(c, 'Permissions', 'Notifications, biometrics'),
        ]),
      ),
    ]);
  }

  Widget _row(AppColors c, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: c.txt2)),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt)),
        ],
      );
}

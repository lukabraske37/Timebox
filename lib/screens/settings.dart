import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
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
            const SectionLabel('Appearance'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.dark_mode, size: 19, color: c.acc),
                  const SizedBox(width: 10),
                  Text('App Theme', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
                ]),
                const SizedBox(height: 14),
                Segmented<String>(
                  values: const ['dark', 'light', 'sepia'],
                  labels: const ['Dark', 'Light', 'Sepia'],
                  value: ['dark', 'light', 'sepia'].contains(store.theme) ? store.theme : 'dark',
                  onChanged: (v) => store.mutate(() => store.theme = v),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            SwitchRow(
              title: 'Color blocks by their icon',
              subtitle: 'Off tints every node with the accent',
              value: store.blockColorIcons,
              onChanged: (v) => store.mutate(() => store.blockColorIcons = v),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Timeline'),
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
            const SectionLabel('General'),
            NavRow(
              icon: Icons.notifications,
              title: 'Notifications & Alerts',
              subtitle: '$channels of 3 channels on',
              onTap: () => open(const NotificationsPage()),
            ),
            const SizedBox(height: 10),
            NavRow(
              icon: Icons.palette,
              title: 'Look and Feel',
              subtitle: '${kThemeLabels[store.theme] ?? 'Dark'} · ${store.accent}',
              onTap: () => open(const LookPage()),
            ),
            const SizedBox(height: 10),
            NavRow(
              icon: Icons.download,
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
    await Notifications.test(alarm: alarm);
    if (mounted) {
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
          Row(children: [
            for (final name in kAccentNames) ...[
              GestureDetector(
                onTap: () => store.mutate(() => store.accent = name),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: AppColors.accentSwatch(name),
                    shape: BoxShape.circle,
                    border: store.accent == name ? Border.all(color: c.txt, width: 2.5) : null,
                  ),
                ),
              ),
            ],
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

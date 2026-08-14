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
      const ScreenTitle(title: 'Settings', subtitle: 'Timebox 1.0 · local only'),
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
              subtitle: 'Export or restore one local file',
              onTap: () => open(const BackupPage()),
            ),
            const SizedBox(height: 10),
            NavRow(
              icon: Icons.fingerprint,
              title: 'Biometric Lock',
              subtitle: store.biometric ? 'On · asks on every launch' : 'Off',
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
              subtitle: 'Timebox 1.0',
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    return SubPage(title: 'Backup', children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('On this phone', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.txt)),
          const SizedBox(height: 6),
          Text(
            '${store.blocks.length} blocks · ${store.tasks.length} tasks · '
            '${store.habits.length} habits · ${store.inbox.length} inbox',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.txt2),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      PrimaryButton(
        label: 'Export a backup file',
        icon: Icons.download,
        onTap: () => Backup.export(store.toJson()),
      ),
      const SizedBox(height: 10),
      PrimaryButton(
        label: 'Restore from a file',
        icon: Icons.upload,
        background: c.surf2,
        foreground: c.txt,
        onTap: () async {
          final data = await Backup.import();
          if (data != null) await store.restore(data);
        },
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => store.resetDemo(),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.restart_alt, size: 19, color: c.danger),
            const SizedBox(width: 8),
            Text('Reset to demo data',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.danger)),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('Nothing leaves the phone. The backup is one plain JSON file you keep yourself.',
            style: TextStyle(fontSize: 12, height: 1.5, color: c.txt3)),
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
    return SubPage(title: 'Biometric Lock', children: [
      SwitchRow(
        title: 'Require unlock',
        subtitle: 'Ask for a fingerprint on every launch',
        value: store.biometric,
        onChanged: (v) async {
          if (v && !await Biometrics.available()) return;
          store.mutate(() => store.biometric = v);
        },
      ),
      const SizedBox(height: 12),
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
          Text('Timebox 1.0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.txt)),
          const SizedBox(height: 6),
          Text('Local-only day planner. No account, no cloud, no analytics.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: c.txt2)),
        ]),
      ),
      const SizedBox(height: 10),
      Panel(
        child: Column(children: [
          _row(c, 'Build', '1.0.0 (1)'),
          const SizedBox(height: 12),
          _row(c, 'Storage', 'On device'),
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

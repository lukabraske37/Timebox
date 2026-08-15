import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'screens/habits.dart';
import 'screens/inbox.dart';
import 'screens/settings.dart';
import 'screens/tasks.dart';
import 'screens/timeline.dart';
import 'services.dart';
import 'sheets.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

void main() {
  runApp(const TimeboxApp());
}

class TimeboxApp extends StatefulWidget {
  const TimeboxApp({super.key});

  @override
  State<TimeboxApp> createState() => _TimeboxAppState();
}

class _TimeboxAppState extends State<TimeboxApp> {
  final store = Store();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final colors = AppColors.resolve(store.theme, store.accent);
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: colors.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.bg,
          systemNavigationBarIconBrightness: colors.isDark ? Brightness.light : Brightness.dark,
        ));
        return AppScope(
          store: store,
          colors: colors,
          child: MaterialApp(
            title: 'Timebox',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: colors.bg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: colors.acc,
                brightness: colors.isDark ? Brightness.dark : Brightness.light,
              ),
              fontFamily: 'Roboto',
              splashFactory: InkSparkle.splashFactory,
            ),
            home: const _Root(),
          ),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!store.booted) return const Onboarding();
    if (store.locked) return const LockScreen();
    return const Shell();
  }
}

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final store = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(26)),
              child: Icon(Icons.schedule, size: 44, color: c.acc),
            ),
            const SizedBox(height: 30),
            Text('Timebox',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: c.txt)),
            const SizedBox(height: 14),
            Text(
              'Plan the day in blocks, capture what comes, keep your streaks. Everything stays on this phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.55, color: c.txt2),
            ),
            const SizedBox(height: 44),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Start',
                onTap: () => store.mutate(() {
                  store.booted = true;
                  store.tab = store.habitsFirst ? 3 : 0;
                }),
              ),
            ),
            const SizedBox(height: 20),
            Text('No account. No cloud. No sync.', style: TextStyle(fontSize: 12.5, color: c.txt3)),
          ]),
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    final store = AppScope.of(context);
    if (await Biometrics.authenticate()) {
      store.mutate(() => store.locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(26)),
                child: Icon(Icons.lock, size: 40, color: c.acc),
              ),
              const SizedBox(height: 22),
              Text('Timebox is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.txt)),
              const SizedBox(height: 8),
              Text('Unlock with your fingerprint to see today.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.txt2)),
              const SizedBox(height: 34),
              GestureDetector(
                onTap: _tryUnlock,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: c.surf2, shape: BoxShape.circle),
                  child: Icon(Icons.fingerprint, size: 36, color: c.acc),
                ),
              ),
              const SizedBox(height: 14),
              Text('Tap to unlock', style: TextStyle(fontSize: 12, color: c.txt3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);

    final screens = [
      const InboxScreen(),
      const TimelineScreen(),
      const TasksScreen(),
      const HabitsScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (store.selectedBlockId != null) {
          store.mutate(() => store.selectedBlockId = null);
        } else if (store.tab != 0) {
          store.mutate(() => store.tab = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: screens[store.tab]),
        bottomNavigationBar: _BottomNav(),
        // Selecting a block opens the timeline's action bar in the same corner,
        // and the Scaffold draws this button over it, right on top of Edit.
        // The action bar covers what you'd want here anyway, so step aside.
        floatingActionButton:
            store.tab == 4 || store.selectedBlockId != null ? null : _Fab(),
        backgroundColor: c.bg,
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final labels = ['New Thought', 'New Block', 'Add Task', 'Add Habit'];
    // Settings has no button, but the Scaffold keeps rebuilding this one while
    // it animates away, so the index has to survive a tab it never labels.
    final tab = store.tab.clamp(0, labels.length - 1);
    final showLabel = store.tab != 1;

    void onPressed() {
      switch (store.tab) {
        case 0:
          openInboxSheet(context);
        case 1:
          openBlockSheet(context);
        case 2:
          openTaskSheet(context);
        case 3:
          openHabitSheet(context);
      }
    }

    if (!showLabel) {
      return FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: c.acc,
        foregroundColor: c.accTxt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, size: 28),
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: c.acc,
      foregroundColor: c.accTxt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.add, size: 26),
      label: Text(labels[tab], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    const icons = [Icons.inbox, Icons.view_timeline, Icons.checklist, Icons.local_fire_department, Icons.settings];
    const labels = ['Inbox', 'Timeline', 'Tasks', 'Habits', 'Settings'];

    return Container(
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 8, right: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < icons.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => store.mutate(() {
                    store.tab = i;
                    store.selectedBlockId = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  // Without this the column takes the whole height the Scaffold
                  // offers the navigation bar, which squeezes the body to zero.
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: store.tab == i ? c.accTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icons[i], size: 22, color: store.tab == i ? c.acc : c.txt3),
                    ),
                    const SizedBox(height: 3),
                    if (store.tab == i)
                      Text(labels[i],
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.acc)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown after scheduling something from the Inbox.
void showToast(BuildContext context, String message) {
  final c = AppScope.colorsOf(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      backgroundColor: c.surf2,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      content: Row(children: [
        Icon(Icons.event_available, size: 19, color: c.acc),
        const SizedBox(width: 9),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt)),
        ),
      ]),
    ));
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

String monthShort(int m) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[m - 1];
}

String dayLabel(Store store, DateTime d) =>
    '${d.day} ${monthName(d.month)} ${d.year}${dateKey(d) == todayKey() ? ' · today' : ''}';

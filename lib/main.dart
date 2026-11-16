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
  // A widget that throws while building would otherwise leave a grey hole in
  // a release build. Say something went wrong and keep the rest of the app up.
  ErrorWidget.builder = (details) => const _BuildFailed();
  runApp(const TimeboxApp());
}

class _BuildFailed extends StatelessWidget {
  const _BuildFailed();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This part of the screen could not be shown.\nYour data is safe — try reopening the app.',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF9AA0A6)),
          ),
        ),
      );
}

class TimeboxApp extends StatefulWidget {
  const TimeboxApp({super.key});

  @override
  State<TimeboxApp> createState() => _TimeboxAppState();
}

class _TimeboxAppState extends State<TimeboxApp> with WidgetsBindingObserver {
  final store = Store();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// True while the app is not in front. With the lock on, the screen is
  /// blanked for that time so the recent-apps view shows nothing of the day.
  bool _away = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.onUndoable = _offerUndo;
    store.load().then((_) {
      final notice = store.loadNotice;
      if (notice != null) _say(notice, seconds: 8);
    });
  }

  void _say(String message, {int seconds = 4, String? action, VoidCallback? onAction}) {
    final c = AppColors.resolve(store.theme, store.accent);
    _messenger.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        backgroundColor: c.surf2,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Text(message, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt)),
        action: action == null
            ? null
            : SnackBarAction(label: action, textColor: c.acc, onPressed: onAction ?? () {}),
      ));
  }

  /// Every removal can be taken back for a few seconds, so a slip of the
  /// thumb on Delete costs nothing.
  void _offerUndo(String label) => _say(label, seconds: 5, action: 'Undo', onAction: store.undo);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android freezes the process while the app is away, so the clock the store
    // keeps can come back stale — check the date on the way in rather than
    // waiting for the next tick.
    if (state == AppLifecycleState.resumed) {
      store.cameBack();
    } else {
      // Paused can be the last thing the app ever hears, so save now.
      store.leftApp();
    }
    final away = state != AppLifecycleState.resumed;
    if (away != _away) setState(() => _away = away);
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
            scaffoldMessengerKey: _messenger,
            // Very large system fonts are honoured up to a point; past it the
            // timeline's fixed gutter and the wheels stop fitting at all.
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Stack(children: [
              if (child != null) child,
              if (_away && store.biometric && store.booted)
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.bg,
                    child: Center(child: Icon(Icons.lock, size: 40, color: colors.txt3)),
                  ),
                ),
            ]),
            ),
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
            const SizedBox(height: 6),
            // Start comes with a sample day to poke at. Anyone who would
            // rather not clear someone else's gym session can skip it.
            TextButton(
              onPressed: () async {
                await store.eraseAll();
                store.mutate(() {
                  store.booted = true;
                  store.tab = store.habitsFirst ? 3 : 1;
                });
              },
              child: Text('Start with an empty planner',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.acc)),
            ),
            const SizedBox(height: 14),
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
    final ok = await Biometrics.authenticate();
    if (ok && mounted) store.mutate(() => store.locked = false);
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
              Text('Unlock with your fingerprint or screen lock to see today.',
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
        body: SafeArea(
          bottom: false,
          // Tabs ease into one another instead of the screen simply being a
          // different one.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 170),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(key: ValueKey(store.tab), child: screens[store.tab]),
          ),
        ),
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
                child: Semantics(
                  button: true,
                  selected: store.tab == i,
                  label: labels[i],
                  excludeSemantics: true,
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
                    // Every tab is named, not just the open one: five bare
                    // icons leave you guessing which is Inbox and which Tasks.
                    Text(labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: store.tab == i ? FontWeight.w700 : FontWeight.w500,
                          color: store.tab == i ? c.acc : c.txt3,
                        )),
                  ]),
                ),
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


String dayLabel(Store store, DateTime d) =>
    '${d.day} ${monthName(d.month)} ${d.year}${dateKey(d) == todayKey() ? ' · today' : ''}';

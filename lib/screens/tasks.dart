import 'package:flutter/material.dart';

import '../models.dart';
import '../sheets.dart';
import '../ui.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final done = store.tasks.where((t) => t.done).length;

    return Column(children: [
      ScreenTitle(
        title: 'Tasks',
        subtitle: '$done completed',
        trailing: GestureDetector(
          onTap: () => _confirmClear(context, done),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.surf, shape: BoxShape.circle),
            child: Icon(Icons.delete_sweep, size: 21, color: c.txt2),
          ),
        ),
      ),
      Expanded(
        child: store.tasks.isEmpty
            ? const SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.checklist,
                  title: 'Add Something',
                  body: "Note it down, get a notification when it's due.",
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                itemCount: store.tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = store.tasks[i];
                  return Panel(
                    radius: 16,
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => store.toggleTask(t.id),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: t.done ? c.acc : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.acc, width: 2.5),
                          ),
                          child: t.done ? Icon(Icons.check, size: 17, color: c.accTxt) : null,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => openTaskSheet(context, existing: t),
                          behavior: HitTestBehavior.opaque,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: t.done ? c.txt3 : c.txt,
                                decoration: t.done ? TextDecoration.lineThrough : null,
                                decorationColor: c.txt3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                height: 22,
                                padding: const EdgeInsets.symmetric(horizontal: 9),
                                decoration: BoxDecoration(
                                  color: t.time == null ? c.surf2 : c.accTint,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Row(children: [
                                  Icon(Icons.schedule, size: 14, color: t.time == null ? c.txt3 : c.acc),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.time == null ? 'Set time' : fmtMins(t.time!, store.use24),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: t.time == null ? c.txt3 : c.acc,
                                    ),
                                  ),
                                ]),
                              ),
                              if (t.time != null) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.notifications, size: 16, color: t.done ? c.txt3 : c.txt2),
                              ],
                            ]),
                          ]),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => openTaskSheet(context, existing: t),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(Icons.edit, size: 18, color: c.txt3),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  void _confirmClear(BuildContext context, int done) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: c.surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clear completed tasks?',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.txt)),
            const SizedBox(height: 10),
            Text(
              done == 0
                  ? 'Nothing is struck through yet, so nothing will be removed.'
                  : 'This removes $done struck-through ${done == 1 ? 'task' : 'tasks'} for good.',
              style: TextStyle(fontSize: 14, height: 1.5, color: c.txt2),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Cancel',
                  background: c.surf2,
                  foreground: c.txt2,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Delete',
                  background: c.danger,
                  foreground: c.onDanger,
                  onTap: () {
                    store.clearDoneTasks();
                    Navigator.pop(context);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

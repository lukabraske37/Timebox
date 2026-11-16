import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../sheets.dart';
import '../store.dart';
import '../ui.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final done = store.tasks.where((t) => t.done).length;
    final left = store.tasks.length - done;
    final sections = taskSections(store.tasks);

    return Column(children: [
      ScreenTitle(
        title: 'Tasks',
        subtitle: store.tasks.isEmpty
            ? 'Nothing to do'
            : [
                if (left > 0) '$left left',
                if (done > 0) '$done done',
              ].join(' · '),
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
                children: [
                  for (final section in sections) ...[
                    _heading(context, store, section),
                    for (final task in section.tasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TaskRow(task: task, section: section),
                      ),
                  ],
                ],
              ),
      ),
    ]);
  }

  Widget _heading(BuildContext context, Store store, TaskSection section) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 0, 4),
      child: Row(children: [
        Expanded(
          child: Text(
            '${section.title.toUpperCase()}  ·  ${section.tasks.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: section.late ? c.danger : c.txt3,
            ),
          ),
        ),
        // Clearing belongs beside the things it clears.
        if (section.done)
          TextButton(
            onPressed: () => _confirmClear(context, section.tasks.length),
            style: TextButton.styleFrom(
              foregroundColor: c.txt2,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          )
        else
          const SizedBox(height: 36),
      ]),
    );
  }

  Future<void> _confirmClear(BuildContext context, int done) async {
    final store = AppScope.of(context);
    final ok = await confirm(
      context,
      title: 'Clear completed tasks?',
      body: 'This removes $done finished ${done == 1 ? 'task' : 'tasks'}.',
      action: 'Clear',
      danger: true,
    );
    if (ok) store.clearDoneTasks();
  }
}

/// One task: its tick, its name, and whatever it has been given by way of a
/// date and a reminder. Tapping the row opens it; swiping it away deletes it.
class _TaskRow extends StatelessWidget {
  final Task task;
  final TaskSection section;
  const _TaskRow({required this.task, required this.section});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final t = task;
    // Under "Today" and "Tomorrow" the heading has already said the day.
    final showDate = t.date != null && (section.late || section.title == 'Later' || section.done);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Dismissible(
        key: ValueKey('task-${t.id}'),
        direction: DismissDirection.endToStart,
        // Deleting offers Undo at the foot of the screen, so a swipe needs no
        // question asked first.
        onDismissed: (_) => store.deleteTask(t.id),
        background: Container(
          color: c.danger.withOpacity(c.isDark ? 0.22 : 0.14),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Icon(Icons.delete_outline, color: c.danger),
        ),
        child: Panel(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          onTap: () => openTaskSheet(context, existing: t),
          child: Row(children: [
            CheckCircle(
              done: t.done,
              color: c.acc,
              size: 26,
              label: t.done ? '${t.title}, done' : '${t.title}, not done',
              onTap: () {
                HapticFeedback.selectionClick();
                store.toggleTask(t.id);
              },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: t.done ? c.txt3 : c.txt,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                      decorationColor: c.txt3,
                    ),
                  ),
                  if (showDate || t.time != null) ...[
                    const SizedBox(height: 6),
                    // Wrapped rather than a Row: a date and a reminder run
                    // out of width on a narrow phone, and belong under each
                    // other rather than clipped.
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (showDate)
                        _Chip(
                          icon: Icons.event,
                          label: dueLabel(t.date!),
                          muted: t.done,
                          danger: section.late,
                        ),
                      if (t.time != null)
                        _Chip(
                          // The icon says which kind of reminder it is.
                          icon: t.alarm ? Icons.alarm : Icons.notifications,
                          label: fmtMins(t.time!, store.use24),
                          muted: t.done,
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One of the small pills under a task's title.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// The task is finished, so this is only a record of what it was.
  final bool muted;
  final bool danger;

  const _Chip({required this.icon, required this.label, this.muted = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final fg = muted ? c.txt3 : (danger ? c.danger : c.acc);
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: muted
            ? c.surf2
            : (danger ? c.danger.withOpacity(c.isDark ? 0.18 : 0.10) : c.accTint),
        borderRadius: BorderRadius.circular(12),
      ),
      // Shrink to the label. Inside a Wrap the incoming width is bounded, so a
      // Row left at its default would stretch each pill across the card.
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import 'icons.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

const List<int> kDurations = [1, 15, 30, 45, 60, 90];
const List<String> kRepeats = ['Once', 'Daily', 'Weekly', 'Monthly'];
const List<String> kAlertPool = [
  'At start of task',
  'At end of task',
  '15m before start',
  '30m before start',
  '1h before start',
];

Future<void> _sheet(BuildContext context, Widget child) {
  final c = AppScope.colorsOf(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surf,
    barrierColor: Colors.black.withOpacity(0.55),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------- block editor

Future<void> openBlockSheet(BuildContext context, {Block? existing}) =>
    _sheet(context, _BlockSheet(existing: existing));

class _BlockSheet extends StatefulWidget {
  final Block? existing;
  const _BlockSheet({this.existing});

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  late TextEditingController _title;
  late String _icon;
  late int _start;
  late int _dur;
  late int _color;
  late String _repeat;
  late List<String> _alerts;
  late List<String> _subtasks;
  bool _fine = false;

  /// Drag distance not yet turned into a five-minute step. Keeping the leftover
  /// is what makes the wheel follow the finger instead of jumping.
  double _wheelPixels = 0;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _title = TextEditingController(text: b?.title ?? '');
    _icon = b?.icon ?? 'label';
    _dur = b?.duration ?? 30;
    _color = b?.color ?? 0;
    _repeat = b?.repeat ?? 'Once';
    _alerts = List.of(b?.alerts ?? const ['At start of task']);
    _subtasks = List.of(b?.subtasks ?? const []);
    _start = b?.start ?? 540;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing == null) {
      _start = AppScope.of(context).nextFreeStart();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final store = AppScope.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final b = widget.existing;
    if (b == null) {
      store.addBlock(Block(
        id: store.newId(),
        date: store.selectedKey,
        icon: _icon,
        title: title,
        start: _start,
        end: _start + _dur,
        color: _color,
        repeat: _repeat,
        alerts: _alerts,
        subtasks: _subtasks,
      ));
    } else {
      store.replaceBlock(Block(
        id: b.id,
        date: b.date,
        icon: _icon,
        title: title,
        start: _start,
        end: _start + _dur,
        color: _color,
        repeat: _repeat,
        alerts: _alerts,
        subtasks: _subtasks,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final editing = widget.existing != null;
    final palette = c.isDark ? kBlockColorsDark : kBlockColorsLight;

    return SheetFrame(
      title: editing ? 'Edit Task' : 'New Task',
      maxHeightFactor: 0.94,
      footer: Column(children: [
        PrimaryButton(label: editing ? 'Save Changes' : 'Create Task', onTap: _save),
        if (editing) ...[
          const SizedBox(height: 10),
          DeleteButton(
            label: 'Delete Task',
            onTap: () {
              store.deleteBlock(widget.existing!.id);
              Navigator.pop(context);
            },
          ),
        ],
      ]),
      children: [
        TitleField(controller: _title, icon: _icon, hint: 'Task title', onPickIcon: () async {
          final picked = await openIconPicker(context, _icon);
          if (picked != null) setState(() => _icon = picked);
        }),
        const SizedBox(height: 24),
        FieldLabel('When?', trailing: _fine ? 'Less…' : 'More…', onTrailing: () => setState(() => _fine = !_fine)),
        const SizedBox(height: 10),
        _timeWheel(store, c),
        if (_fine) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _tinyStep(c, '− 5 min', () => setState(() => _start = (_start - 5).clamp(0, 1435))),
            const SizedBox(width: 12),
            _tinyStep(c, '+ 5 min', () => setState(() => _start = (_start + 5).clamp(0, 1435))),
          ]),
        ],
        const SizedBox(height: 22),
        FieldLabel('How long?'),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < kDurations.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: PillButton(
                label: durLabel(kDurations[i]),
                height: 40,
                selected: _dur == kDurations[i],
                onTap: () => setState(() => _dur = kDurations[i]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 22),
        FieldLabel('What color?'),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < palette.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _color = i),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette[i],
                  shape: BoxShape.circle,
                  border: _color == i ? Border.all(color: c.txt, width: 2.5) : null,
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 22),
        FieldLabel('How often?'),
        const SizedBox(height: 12),
        Segmented<String>(
          values: kRepeats,
          labels: kRepeats,
          value: _repeat,
          onChanged: (v) => setState(() => _repeat = v),
        ),
        const SizedBox(height: 22),
        FieldLabel('Needs alerts?'),
        const SizedBox(height: 12),
        for (final a in _alerts) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.notifications_active, size: 19, color: c.acc),
              const SizedBox(width: 12),
              Expanded(
                child: Text(a, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
              ),
              GestureDetector(
                onTap: () => setState(() => _alerts.remove(a)),
                child: Icon(Icons.close, size: 18, color: c.txt3),
              ),
            ]),
          ),
        ],
        GestureDetector(
          onTap: () {
            final next = kAlertPool.firstWhere((a) => !_alerts.contains(a), orElse: () => '');
            if (next.isNotEmpty) setState(() => _alerts.add(next));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: c.line, width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline, size: 19, color: c.acc),
              const SizedBox(width: 8),
              Text('Add Alert', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.acc)),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < _subtasks.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
            decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.subdirectory_arrow_right, size: 18, color: c.txt3),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _subtasks[i],
                  onChanged: (v) => _subtasks[i] = v,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Subtask',
                    hintStyle: TextStyle(color: c.txt3),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _subtasks.removeAt(i)),
                child: Icon(Icons.close, size: 17, color: c.txt3),
              ),
            ]),
          ),
        ],
        GestureDetector(
          onTap: () => setState(() => _subtasks.add('')),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Icons.add_circle_outline, size: 19, color: c.acc),
              const SizedBox(width: 8),
              Text('Add Subtask', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.acc)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _tinyStep(AppColors c, String label, VoidCallback onTap) => Material(
        color: c.surf2,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.txt2)),
          ),
        ),
      );

  Widget _timeWheel(Store store, AppColors c) {
    Widget faded(String text, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(text, style: TextStyle(fontSize: 14, color: c.txt3.withOpacity(0.7))),
          ),
        );

    // One five-minute step per this many pixels dragged.
    const pixelsPerStep = 7.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _wheelPixels = 0,
      onVerticalDragUpdate: (d) {
        // Carry the leftover into the next event. Rounding each event on its
        // own threw away anything under half a step and turned a steady drag
        // into 5, 10 and 15 minute jumps that depended on the frame rate.
        _wheelPixels -= d.primaryDelta!;
        final steps = (_wheelPixels / pixelsPerStep).truncate();
        if (steps == 0) return;
        _wheelPixels -= steps * pixelsPerStep;
        setState(() => _start = (_start + steps * 5).clamp(0, 1425));
      },
      onVerticalDragEnd: (_) => _wheelPixels = 0,
      child: Column(children: [
        faded('${fmtMins(_start - 15, store.use24)} – ${fmtMins(_start, store.use24)}',
            () => setState(() => _start = (_start - 15).clamp(0, 1425))),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(24)),
          child: Text('${fmtMins(_start, store.use24)} – ${fmtMins(_start + _dur, store.use24)}',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.accTxt)),
        ),
        faded(
            '${fmtMins(_start + _dur, store.use24)} – ${fmtMins(_start + _dur + 15, store.use24)}',
            () => setState(() => _start = (_start + 15).clamp(0, 1425))),
        const SizedBox(height: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(17)),
          child: Row(children: [
            Icon(Icons.calendar_month, size: 17, color: c.acc),
            const SizedBox(width: 7),
            Text(
              '${store.selected.day} ${monthShort(store.selected.month)} ${store.selected.year}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.txt2),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------- inbox / task / habit

Future<void> openInboxSheet(BuildContext context, {InboxItem? existing}) =>
    _sheet(context, _SimpleSheet(kind: _SimpleKind.inbox, inbox: existing));

Future<void> openTaskSheet(BuildContext context, {Task? existing}) =>
    _sheet(context, _SimpleSheet(kind: _SimpleKind.task, task: existing));

Future<void> openHabitSheet(BuildContext context, {Habit? existing}) =>
    _sheet(context, _SimpleSheet(kind: _SimpleKind.habit, habit: existing));

enum _SimpleKind { inbox, task, habit }

class _SimpleSheet extends StatefulWidget {
  final _SimpleKind kind;
  final InboxItem? inbox;
  final Task? task;
  final Habit? habit;

  const _SimpleSheet({required this.kind, this.inbox, this.task, this.habit});

  @override
  State<_SimpleSheet> createState() => _SimpleSheetState();
}

class _SimpleSheetState extends State<_SimpleSheet> {
  late TextEditingController _title;
  late String _icon;
  int _dur = 30;
  bool _reminder = false;
  int _time = 540;

  @override
  void initState() {
    super.initState();
    switch (widget.kind) {
      case _SimpleKind.inbox:
        _title = TextEditingController(text: widget.inbox?.title ?? '');
        _icon = widget.inbox?.icon ?? 'label';
        _dur = widget.inbox?.dur ?? 30;
      case _SimpleKind.task:
        _title = TextEditingController(text: widget.task?.title ?? '');
        _icon = 'checklist';
        _reminder = widget.task?.time != null;
        _time = widget.task?.time ?? 540;
      case _SimpleKind.habit:
        _title = TextEditingController(text: widget.habit?.title ?? '');
        _icon = widget.habit?.icon ?? 'local_fire_department';
        _reminder = widget.habit?.time != null;
        _time = widget.habit?.time ?? 480;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _editing => widget.inbox != null || widget.task != null || widget.habit != null;

  void _save() {
    final store = AppScope.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      Navigator.pop(context);
      return;
    }
    switch (widget.kind) {
      case _SimpleKind.inbox:
        final item = InboxItem(id: widget.inbox?.id ?? store.newId(), icon: _icon, title: title, dur: _dur);
        widget.inbox == null ? store.addInbox(item) : store.replaceInbox(item);
      case _SimpleKind.task:
        final t = Task(
          id: widget.task?.id ?? store.newId(),
          title: title,
          time: _reminder ? _time : null,
          done: widget.task?.done ?? false,
        );
        widget.task == null ? store.addTask(t) : store.replaceTask(t);
      case _SimpleKind.habit:
        if (widget.habit == null) {
          store.addHabit(Habit(id: store.newId(), title: title, icon: _icon, time: _reminder ? _time : null));
        } else {
          store.mutate(() {
            widget.habit!
              ..title = title
              ..icon = _icon
              ..time = _reminder ? _time : null;
          });
        }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final titles = {
      _SimpleKind.inbox: _editing ? 'Edit Inbox Block' : 'New Inbox Task',
      _SimpleKind.task: _editing ? 'Edit Task' : 'Add Task',
      _SimpleKind.habit: _editing ? 'Edit Habit' : 'Add New Habit',
    };
    final ctas = {
      _SimpleKind.inbox: _editing ? 'Save Changes' : 'Add to Inbox',
      _SimpleKind.task: _editing ? 'Save Changes' : 'Add Task',
      _SimpleKind.habit: _editing ? 'Save Changes' : 'Add Habit',
    };
    final hints = {
      _SimpleKind.inbox: 'What is on your mind?',
      _SimpleKind.task: 'Task title',
      _SimpleKind.habit: 'Habit title',
    };

    return SheetFrame(
      title: titles[widget.kind]!,
      footer: Column(children: [
        PrimaryButton(label: ctas[widget.kind]!, onTap: _save),
        if (_editing && widget.kind != _SimpleKind.habit) ...[
          const SizedBox(height: 10),
          DeleteButton(
            label: 'Delete',
            onTap: () {
              if (widget.inbox != null) store.deleteInbox(widget.inbox!.id);
              if (widget.task != null) store.deleteTask(widget.task!.id);
              Navigator.pop(context);
            },
          ),
        ],
      ]),
      children: [
        TitleField(
          controller: _title,
          icon: _icon,
          hint: hints[widget.kind]!,
          onPickIcon: () async {
            final picked = await openIconPicker(context, _icon);
            if (picked != null) setState(() => _icon = picked);
          },
        ),
        if (widget.kind == _SimpleKind.inbox) ...[
          const SizedBox(height: 24),
          FieldLabel('How long?'),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < kDurations.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: PillButton(
                  label: durLabel(kDurations[i]),
                  height: 40,
                  selected: _dur == kDurations[i],
                  onTap: () => setState(() => _dur = kDurations[i]),
                ),
              ),
            ],
          ]),
        ],
        if (widget.kind != _SimpleKind.inbox) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.alarm, size: 20, color: c.acc),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add Reminder',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
                  Text(_reminder ? 'Notification at ${fmtMins(_time, store.use24)}' : 'Off',
                      style: TextStyle(fontSize: 12, color: c.txt3)),
                ]),
              ),
              Switch(
                value: _reminder,
                onChanged: (v) => setState(() => _reminder = v),
                activeColor: c.accTxt,
                activeTrackColor: c.acc,
                inactiveThumbColor: c.txt3,
                inactiveTrackColor: c.node,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ]),
          ),
          if (_reminder) ...[
            const SizedBox(height: 12),
            TimeStepper(
              minutes: _time,
              use24: store.use24,
              onChanged: (v) => setState(() => _time = v),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- shared parts

/// The destructive action at the foot of an editor sheet. Tinted rather than
/// bare text so it reads as a button and gives the tap somewhere to land.
class DeleteButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DeleteButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Material(
      color: c.danger.withOpacity(c.isDark ? 0.14 : 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.delete_outline, size: 21, color: c.danger),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.danger)),
          ]),
        ),
      ),
    );
  }
}

class SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget footer;
  final double maxHeightFactor;

  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
    this.maxHeightFactor = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Row(children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.txt)),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.surf2, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 20, color: c.txt2),
              ),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          // The sheet runs to the very bottom of the screen, so the footer has
          // to clear the system navigation bar itself — otherwise the last
          // action in it sits under the back and home buttons. This goes to
          // zero while the keyboard is up, which _sheet already pads for.
          padding: EdgeInsets.fromLTRB(20, 12, 20, 22 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(width: double.infinity, child: footer),
        ),
      ]),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailing;

  const FieldLabel(this.text, {super.key, this.trailing, this.onTrailing});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Row(children: [
      Expanded(
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt2)),
      ),
      if (trailing != null)
        GestureDetector(
          onTap: onTrailing,
          child: Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.acc)),
        ),
    ]);
  }
}

class TitleField extends StatelessWidget {
  final TextEditingController controller;
  final String icon;
  final String hint;
  final VoidCallback onPickIcon;

  const TitleField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onPickIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Row(children: [
      GestureDetector(
        onTap: onPickIcon,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(14)),
          child: Icon(iconFor(icon), size: 23, color: c.acc),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.txt),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.txt3, fontWeight: FontWeight.w500),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.line, width: 1.5)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.acc, width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

/// Hour / minute stepper with AM-PM, used for every exact alarm time.
class TimeStepper extends StatelessWidget {
  final int minutes;
  final bool use24;
  final ValueChanged<int> onChanged;

  const TimeStepper({super.key, required this.minutes, required this.use24, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final h24 = minutes ~/ 60;
    final hourText = use24 ? h24.toString().padLeft(2, '0') : ((h24 % 12 == 0) ? '12' : (h24 % 12).toString());
    final minText = (minutes % 60).toString().padLeft(2, '0');

    Widget stepper(String value, VoidCallback up, VoidCallback down) => Column(children: [
          _arrow(c, Icons.keyboard_arrow_up, up),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(value,
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, color: c.txt)),
          ),
          _arrow(c, Icons.keyboard_arrow_down, down),
        ]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          stepper(hourText, () => onChanged((minutes + 60) % 1440), () => onChanged((minutes + 1380) % 1440)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(':', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: c.txt3)),
          ),
          stepper(
            minText,
            () => onChanged(((minutes ~/ 5) * 5 + 5) % 1440),
            () => onChanged(((minutes ~/ 5) * 5 + 1435) % 1440),
          ),
          if (!use24) ...[
            const SizedBox(width: 10),
            Column(children: [
              _ampm(c, 'AM', minutes < 720, () => onChanged(minutes >= 720 ? minutes - 720 : minutes)),
              const SizedBox(height: 5),
              _ampm(c, 'PM', minutes >= 720, () => onChanged(minutes < 720 ? minutes + 720 : minutes)),
            ]),
          ],
        ]),
        const SizedBox(height: 16),
        Row(children: [
          for (final t in [420, 720, 1080, 1320]) ...[
            if (t != 420) const SizedBox(width: 6),
            Expanded(
              child: PillButton(
                label: fmtMins(t, use24),
                height: 34,
                selected: minutes == t,
                onTap: () => onChanged(t),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _arrow(AppColors c, IconData icon, VoidCallback onTap) => Material(
        color: c.surf,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(width: 46, height: 32, child: Icon(icon, size: 19, color: c.txt2)),
        ),
      );

  Widget _ampm(AppColors c, String label, bool on, VoidCallback onTap) => Material(
        color: on ? c.acc : c.surf,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 34,
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: on ? c.accTxt : c.txt2)),
          ),
        ),
      );
}

// ---------------------------------------------------------------- icon picker

Future<String?> openIconPicker(BuildContext context, String current) {
  return Navigator.of(context).push<String>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _IconPicker(current: current),
  ));
}

class _IconPicker extends StatefulWidget {
  final String current;
  const _IconPicker({required this.current});

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final q = _query.trim().toLowerCase();
    var entries = kIconCategories.entries.toList();
    if (q.isNotEmpty) {
      entries = entries
          .map((e) => MapEntry(e.key, e.value.where((n) => n.contains(q)).toList()))
          .where((e) => e.value.isNotEmpty)
          .toList();
    } else if (_category != null) {
      entries = entries.where((e) => e.key == _category).toList();
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: c.txt),
              ),
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: c.surf, borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    Icon(Icons.search, size: 20, color: c.txt3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: TextStyle(fontSize: 15, color: c.txt),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search',
                          hintStyle: TextStyle(color: c.txt3),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              children: [
                for (final entry in entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(iconFor(entry.value.first), size: 17, color: c.txt2),
                      const SizedBox(width: 8),
                      Text(entry.key,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt2)),
                    ]),
                  ),
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    children: [
                      for (final name in entry.value)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, name),
                          child: Container(
                            decoration: BoxDecoration(
                              color: name == widget.current ? c.accTint : c.surf,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(iconFor(name), size: 22, color: name == widget.current ? c.acc : c.txt2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
              ],
            ),
          ),
          Container(
            color: c.surf,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final entry in kIconCategories.entries)
                  GestureDetector(
                    onTap: () => setState(() {
                      _category = _category == entry.key ? null : entry.key;
                      _query = '';
                    }),
                    child: Container(
                      width: 44,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: _category == entry.key ? c.accTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconFor(entry.value.first),
                          size: 20, color: _category == entry.key ? c.acc : c.txt3),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

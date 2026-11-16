import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

// Five minutes is the smallest step the wheels and steppers can express, so
// the shortest preset matches it rather than offering a length nothing else in
// the app can reach.
const List<int> kDurations = [5, 15, 30, 45, 60, 90];
const List<String> kRepeats = ['Once', 'Daily', 'Weekly', 'Monthly'];

Future<void> _sheet(BuildContext context, Widget child) {
  final c = AppScope.colorsOf(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surf,
    barrierColor: Colors.black.withOpacity(0.55),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    // Read the keyboard inset from the sheet's own context. Reading it from the
    // caller's froze it at whatever it was when the sheet opened — always zero,
    // since the title field autofocuses a moment later — so the sheet sat still
    // while the keyboard rose over the field being typed into.
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------- block editor

/// [startAt] and [fill] pre-load the sheet for a slot the user tapped, so a
/// gap on the timeline can be turned into a block without setting the time.
Future<void> openBlockSheet(BuildContext context, {Block? existing, int? startAt, int? fill}) =>
    _sheet(context, _BlockSheet(existing: existing, startAt: startAt, fill: fill));

class _BlockSheet extends StatefulWidget {
  final Block? existing;
  final int? startAt;
  final int? fill;
  const _BlockSheet({this.existing, this.startAt, this.fill});

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
  late Set<String> _rings;
  late List<String> _subtasks;
  bool _fine = false;
  bool _longer = false;

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
    _rings = {...?b?.rings};
    _subtasks = List.of(b?.subtasks ?? const []);
    _start = b?.start ?? widget.startAt ?? 540;
    if (b == null && widget.fill != null) _dur = widget.fill!;
  }

  bool _startPicked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope rebuilds on every store notification, the clock tick included,
    // so this runs again and again while the sheet is open. Only the first pass
    // may choose a start time — after that it is the user's.
    if (widget.existing == null && widget.startAt == null && !_startPicked) {
      _startPicked = true;
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
        rings: _alerts.where(_rings.contains).toList(),
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
        rings: _alerts.where(_rings.contains).toList(),
      ));
    }
    Navigator.pop(context);
  }

  /// Opens the editor for [existing], or for a new alert when null.
  Future<void> _editAlert(String? existing) async {
    final store = AppScope.of(context);
    final base = AppScope.colorsOf(context);
    final colors = store.blockColorIcons ? base.withAccent(base.item(_color)) : base;
    final result = await showDialog<({String label, bool ring})>(
      context: context,
      // A dialog is built above the sheet, so it is handed the sheet's colours.
      builder: (_) => AppScope(
        store: store,
        colors: colors,
        child: AlertEditor(
          label: existing ?? (_alerts.contains(kAtStart) ? alertLabel(15) : kAtStart),
          ring: existing != null && _rings.contains(existing),
          start: _start,
          duration: _dur,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      // Two alerts at the same moment would only ring twice, so the edited
      // one replaces any other that says the same thing.
      final at = existing == null ? _alerts.length : _alerts.indexOf(existing);
      _alerts.remove(existing);
      _rings.remove(existing);
      _alerts.remove(result.label);
      _alerts.insert(at.clamp(0, _alerts.length), result.label);
      result.ring ? _rings.add(result.label) : _rings.remove(result.label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final base = AppScope.colorsOf(context);
    final editing = widget.existing != null;
    // The sheet wears the block's own colour. A colour chosen half way down
    // then shows at once on everything in view — the title tile, the time,
    // the chips, the button — instead of only on a tile that has scrolled
    // out of sight by the time the swatches are reached.
    final tint = store.blockColorIcons ? base.item(_color) : null;
    final c = tint == null ? base : base.withAccent(tint);

    return SheetFrame(
      title: editing ? 'Edit Block' : 'New Block',
      maxHeightFactor: 0.94,
      accent: tint,
      header: TitleField(
        controller: _title,
        icon: _icon,
        hint: 'Block title',
        autofocus: !editing,
        onPickIcon: () async {
          final picked = await openIconPicker(context, _icon, tint: c.acc);
          if (picked != null) setState(() => _icon = picked);
        },
      ),
      footer: Column(children: [
        PrimaryButton(label: editing ? 'Save Changes' : 'Create Block', onTap: _save),
        if (editing) ...[
          const SizedBox(height: 10),
          DeleteButton(
            label: 'Delete Block',
            onTap: () {
              store.deleteBlock(widget.existing!.id);
              Navigator.pop(context);
            },
          ),
        ],
      ]),
      children: [
        FieldLabel('When?', trailing: _fine ? 'Less…' : 'More…', onTrailing: () => setState(() => _fine = !_fine)),
        const SizedBox(height: 10),
        _timeWheel(store, c),
        if (_fine) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _tinyStep(c, '− 5 min',
                () => setState(() => _start = snapToStep(_start - kStep).clamp(0, 1435))),
            const SizedBox(width: 12),
            _tinyStep(c, '+ 5 min',
                () => setState(() => _start = snapToStep(_start + kStep).clamp(0, 1435))),
          ]),
        ],
        const SizedBox(height: 22),
        FieldLabel('How long?',
            trailing: _longer ? 'Less…' : 'More…',
            onTrailing: () => setState(() => _longer = !_longer)),
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
        if (_longer) ...[
          const SizedBox(height: 12),
          DurationPicker(minutes: _dur, onChanged: (v) => setState(() => _dur = v)),
        ] else if (!kDurations.contains(_dur)) ...[
          // A length picked on the wheel has no chip to light up, so name it.
          const SizedBox(height: 10),
          Text('Set to ${durLabel(_dur)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.acc)),
        ],
        if (store.blockColorIcons) ...[
          const SizedBox(height: 22),
          const FieldLabel('What color?'),
          const SizedBox(height: 12),
          ColorRow(
            value: _color,
            onChanged: (v) {
              setState(() => _color = v ?? 0);
              // A block that already exists changes there and then, not only
              // on Save: closing the sheet any other way used to throw the
              // colour away without a word.
              if (editing) store.recolorBlock(widget.existing!.id, _color);
            },
          ),
        ],
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
          // Tap a row to set exactly when it fires and whether it rings.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _editAlert(a),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 6, 2, 6),
              decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(_rings.contains(a) ? Icons.alarm : Icons.notifications_active, size: 19, color: c.acc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(alertText(a), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
                    const SizedBox(height: 2),
                    Text(
                      '${_rings.contains(a) ? 'Alarm' : 'Notification'} · '
                      '${fmtMins(alertTime(a, _start, _dur) % 1440, store.use24)}',
                      style: TextStyle(fontSize: 12, color: c.txt3),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _alerts.remove(a);
                    _rings.remove(a);
                  }),
                  icon: Icon(Icons.close, size: 18, color: c.txt3),
                ),
              ]),
            ),
          ),
        ],
        GestureDetector(
          onTap: () => _editAlert(null),
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
        HapticFeedback.selectionClick();
        setState(() => _start = snapToStep(_start + steps * kStep).clamp(0, 1425));
      },
      onVerticalDragEnd: (_) => _wheelPixels = 0,
      child: Column(children: [
        faded('${fmtMins(_start - 15, store.use24)} – ${fmtMins(_start, store.use24)}',
            () => setState(() => _start = snapToStep(_start - 15).clamp(0, 1425))),
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
            () => setState(() => _start = snapToStep(_start + 15).clamp(0, 1425))),
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
  bool _longer = false;
  bool _reminder = false;
  bool _alarm = false;
  int _time = 540;
  String? _date;

  /// The entry's place in the block palette. Null is a habit wearing the
  /// app's accent.
  int? _color;

  @override
  void initState() {
    super.initState();
    switch (widget.kind) {
      case _SimpleKind.inbox:
        _title = TextEditingController(text: widget.inbox?.title ?? '');
        _icon = widget.inbox?.icon ?? 'label';
        _dur = widget.inbox?.dur ?? 30;
        _color = widget.inbox?.color ?? 0;
      case _SimpleKind.task:
        _title = TextEditingController(text: widget.task?.title ?? '');
        _icon = 'checklist';
        _reminder = widget.task?.time != null;
        _time = widget.task?.time ?? 540;
        _date = widget.task?.date;
        _alarm = widget.task?.alarm ?? false;
      case _SimpleKind.habit:
        _title = TextEditingController(text: widget.habit?.title ?? '');
        _icon = widget.habit?.icon ?? 'local_fire_department';
        _reminder = widget.habit?.time != null;
        _time = widget.habit?.time ?? 480;
        _alarm = widget.habit?.alarm ?? false;
        _color = widget.habit?.color;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// Days from today to the chosen due date, or null when there is none.
  int? get _dueIn => _date == null ? null : daysUntil(_date!);

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
        final item = InboxItem(
            id: widget.inbox?.id ?? store.newId(), icon: _icon, title: title, dur: _dur, color: _color ?? 0);
        widget.inbox == null ? store.addInbox(item) : store.replaceInbox(item);
      case _SimpleKind.task:
        final t = Task(
          id: widget.task?.id ?? store.newId(),
          title: title,
          time: _reminder ? _time : null,
          date: _date,
          done: widget.task?.done ?? false,
          alarm: _reminder && _alarm,
        );
        widget.task == null ? store.addTask(t) : store.replaceTask(t);
      case _SimpleKind.habit:
        if (widget.habit == null) {
          store.addHabit(Habit(
            id: store.newId(),
            title: title,
            icon: _icon,
            time: _reminder ? _time : null,
            alarm: _reminder && _alarm,
            color: _color,
          ));
        } else {
          store.mutate(() {
            widget.habit!
              ..title = title
              ..icon = _icon
              ..time = _reminder ? _time : null
              ..alarm = _reminder && _alarm
              ..color = _color;
          });
        }
    }
    Navigator.pop(context);
  }

  /// A full calendar, for a due date further off than the two quick pills.
  /// Themed by hand because the stock dialog otherwise arrives in Material
  /// blue, whatever the app is set to.
  Future<void> _pickDate() async {
    final c = AppScope.colorsOf(context);
    final now = clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date == null ? now : keyToDate(_date!),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) {
        final base = c.isDark ? ThemeData.dark() : ThemeData.light();
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: c.acc,
              onPrimary: c.accTxt,
              surface: c.surf,
              onSurface: c.txt,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: c.surf,
              headerBackgroundColor: c.acc,
              headerForegroundColor: c.accTxt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _date = dateKey(picked));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final base = AppScope.colorsOf(context);
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

    final isTask = widget.kind == _SimpleKind.task;
    // Inbox entries and habits carry a colour of their own; a task is a line
    // in a list and wears the accent like the rest of the app.
    final tint = isTask || !store.blockColorIcons ? null : base.item(_color);
    final c = tint == null ? base : base.withAccent(tint);

    return SheetFrame(
      title: titles[widget.kind]!,
      accent: tint,
      header: TitleField(
        controller: _title,
        // A task has no icon to choose, so it gets no tile pretending it has.
        icon: isTask ? null : _icon,
        hint: hints[widget.kind]!,
        autofocus: !_editing,
        onPickIcon: () async {
          final picked = await openIconPicker(context, _icon, tint: c.acc);
          if (picked != null) setState(() => _icon = picked);
        },
      ),
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
        if (widget.kind == _SimpleKind.inbox) ...[
          FieldLabel('How long?',
              trailing: _longer ? 'Less…' : 'More…',
              onTrailing: () => setState(() => _longer = !_longer)),
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
          if (_longer) ...[
            const SizedBox(height: 12),
            DurationPicker(minutes: _dur, onChanged: (v) => setState(() => _dur = v)),
          ] else if (!kDurations.contains(_dur)) ...[
            const SizedBox(height: 10),
            Text('Set to ${durLabel(_dur)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.acc)),
          ],
        ],
        if (widget.kind == _SimpleKind.task) ...[
          FieldLabel(
            'When is it due?',
            trailing: _date == null ? null : 'Clear',
            onTrailing: _date == null ? null : () => setState(() => _date = null),
          ),
          const SizedBox(height: 12),
          // Today and tomorrow cover most of what gets written down; the third
          // pill opens a calendar and then names the day it is holding, so the
          // chosen date stays visible instead of hiding behind "Pick…".
          Row(children: [
            Expanded(
              child: PillButton(
                label: 'Today',
                height: 40,
                selected: _dueIn == 0,
                onTap: () => setState(() => _date = todayKey()),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: PillButton(
                label: 'Tomorrow',
                height: 40,
                selected: _dueIn == 1,
                onTap: () => setState(
                    () => _date = dayKey(1)),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: PillButton(
                label: _dueIn != null && (_dueIn! < 0 || _dueIn! > 1) ? dueLabel(_date!) : 'Pick a day',
                height: 40,
                selected: _dueIn != null && (_dueIn! < 0 || _dueIn! > 1),
                onTap: _pickDate,
              ),
            ),
          ]),
          if (_date == null) ...[
            const SizedBox(height: 10),
            Text('No date — it waits at the bottom of the list until you give it one.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: c.txt3)),
          ] else if (_dueIn! < 0) ...[
            const SizedBox(height: 10),
            Text('${dueLabel(_date!)} has already gone by.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.danger)),
          ],
        ],
        if (!isTask && store.blockColorIcons) ...[
          if (widget.kind == _SimpleKind.inbox) const SizedBox(height: 22),
          const FieldLabel('What color?'),
          const SizedBox(height: 12),
          ColorRow(
            value: _color,
            // A habit may go without one and follow the accent; an Inbox
            // entry hands its colour to every block made from it, so it
            // always has one.
            allowNone: widget.kind == _SimpleKind.habit,
            onChanged: (v) {
              setState(() => _color = widget.kind == _SimpleKind.inbox ? (v ?? 0) : v);
              // Something that already exists changes there and then.
              if (widget.inbox != null) store.mutate(() => widget.inbox!.color = _color ?? 0);
              if (widget.habit != null) store.mutate(() => widget.habit!.color = _color);
            },
          ),
        ],
        if (widget.kind != _SimpleKind.inbox) ...[
          SizedBox(height: isTask ? 22 : 24),
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
                  Text(
                      _reminder
                          ? _date == null
                              ? '${_alarm ? 'Alarm' : 'Notification'} at ${fmtMins(_time, store.use24)}'
                              : '${_alarm ? 'Alarm ' : ''}${dueLabel(_date!)} at ${fmtMins(_time, store.use24)}'
                          : 'Off',
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
            AlarmChoice(alarm: _alarm, onChanged: (v) => setState(() => _alarm = v)),
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

/// Sets one alert on a block: when it fires, to the minute, and whether it
/// arrives as a notification or rings as an alarm.
class AlertEditor extends StatefulWidget {
  final String label;
  final bool ring;
  final int start;
  final int duration;

  const AlertEditor({super.key, required this.label, required this.ring, required this.start, required this.duration});

  @override
  State<AlertEditor> createState() => _AlertEditorState();
}

class _AlertEditorState extends State<AlertEditor> {
  /// 'before', 'start' or 'end'.
  late String _when;
  late int _before;
  late bool _ring;

  static const _presets = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    final before = alertBefore(widget.label);
    _when = before == null ? 'end' : (before == 0 ? 'start' : 'before');
    _before = before == null || before == 0 ? 15 : before;
    _ring = widget.ring;
  }

  String get _label => switch (_when) { 'end' => kAtEnd, 'start' => kAtStart, _ => alertLabel(_before) };

  void _nudge(int by) => setState(() => _before = (_before + by).clamp(1, 24 * 60));

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final fires = alertTime(_label, widget.start, widget.duration);

    Widget step(String text, int by) => Material(
          color: c.surf2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _nudge(by),
            child: SizedBox(
              width: 46,
              height: 40,
              child: Center(
                child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.txt2)),
              ),
            ),
          ),
        );

    return Dialog(
      backgroundColor: c.surf,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alert', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.txt)),
          const SizedBox(height: 4),
          Text(
            '${fires < 0 ? 'The evening before, ' : ''}${fmtMins(fires % 1440, store.use24)}',
            key: const ValueKey('alert-fires'),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.acc),
          ),
          const SizedBox(height: 16),
          Segmented<String>(
            values: const ['before', 'start', 'end'],
            labels: const ['Before', 'At start', 'At end'],
            value: _when,
            onChanged: (v) => setState(() => _when = v),
          ),
          if (_when == 'before') ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              step('−5', -5),
              step('−1', -1),
              Expanded(
                child: Text(durLabel(_before),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.txt)),
              ),
              step('+1', 1),
              step('+5', 5),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final m in _presets) ...[
                if (m != _presets.first) const SizedBox(width: 6),
                Expanded(
                  child: PillButton(
                    label: durLabel(m),
                    height: 34,
                    selected: _before == m,
                    onTap: () => setState(() => _before = m),
                  ),
                ),
              ],
            ]),
          ],
          const SizedBox(height: 18),
          AlarmChoice(alarm: _ring, onChanged: (v) => setState(() => _ring = v)),
          const SizedBox(height: 20),
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
                label: 'Done',
                onTap: () => Navigator.pop(context, (label: _label, ring: _ring)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Whether a reminder arrives as a notification or rings as an alarm.
class AlarmChoice extends StatelessWidget {
  final bool alarm;
  final ValueChanged<bool> onChanged;

  const AlarmChoice({super.key, required this.alarm, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Segmented<bool>(
        values: const [false, true],
        labels: const ['Notification', 'Alarm'],
        value: alarm,
        onChanged: onChanged,
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          alarm
              ? 'Rings on the alarm volume until you stop or snooze it, even on silent.'
              : 'One quiet notification, at whatever volume the phone is on.',
          style: TextStyle(fontSize: 12, height: 1.4, color: c.txt3),
        ),
      ),
    ]);
  }
}

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

  /// Stays put above the scrolling part. The editors put the title field
  /// here, so what is being edited — its name, icon and colour — is in view
  /// the whole time, however far down the sheet has been scrolled.
  final Widget? header;

  /// When set, everything in the sheet uses this in place of the app's accent.
  final Color? accent;

  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
    this.maxHeightFactor = 0.8,
    this.header,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppScope.colorsOf(context);
    final c = accent == null ? base : base.withAccent(accent!);
    final frame = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(children: [
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: c.txt)),
            ),
            Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.surf2, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 20, color: c.txt2),
                  ),
                ),
              ),
            ),
          ]),
        ),
        if (header != null)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 18), child: header),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
    return accent == null ? frame : AppScope(store: AppScope.of(context), colors: c, child: frame);
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

/// The name of whatever is being edited, with its icon beside it. The tile
/// wears the accent of the sheet it sits in, which an editor sets to the
/// colour of the thing itself.
class TitleField extends StatelessWidget {
  final TextEditingController controller;

  /// Null for something that has no icon: the tile is left out altogether.
  final String? icon;
  final String hint;
  final VoidCallback? onPickIcon;

  /// Raising the keyboard is right for something new, which needs a name
  /// first. Something that exists is as likely opened to move its time.
  final bool autofocus;

  const TitleField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.onPickIcon,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Row(children: [
      if (icon != null) ...[
        Semantics(
          button: true,
          label: 'Change icon',
          child: GestureDetector(
            onTap: onPickIcon,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.acc.withOpacity(c.isDark ? 0.20 : 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconFor(icon!), size: 25, color: c.acc),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: c.acc,
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

/// The block palette as a grid of swatches.
class ColorRow extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Offers "no colour of its own" as the first swatch, drawn in the app's
  /// real accent.
  final bool allowNone;

  const ColorRow({super.key, required this.value, required this.onChanged, this.allowNone = false});

  @override
  Widget build(BuildContext context) {
    // The sheet's own accent is the colour being picked, so "follow the app"
    // has to be drawn from the palette the whole app runs on.
    final store = AppScope.of(context);
    final app = AppColors.resolve(store.theme, store.accent);
    final count = app.isDark ? kBlockColorsDark.length : kBlockColorsLight.length;

    Widget swatch(int? index) {
      final color = app.item(index);
      final on = value == index;
      return Semantics(
        button: true,
        selected: on,
        label: index == null ? 'App accent' : kBlockColorNames[index % kBlockColorNames.length],
        child: GestureDetector(
          key: ValueKey('color-${index ?? 'accent'}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 40,
            height: 40,
            padding: EdgeInsets.all(on ? 4 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: on ? Border.all(color: color, width: 2.5) : null,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: on
                  ? Icon(Icons.check, size: 17, color: AppColors.onColor(color))
                  : (index == null
                      ? Icon(Icons.auto_awesome, size: 16, color: AppColors.onColor(color))
                      : null),
            ),
          ),
        ),
      );
    }

    return Wrap(spacing: 11, runSpacing: 11, children: [
      if (allowNone) swatch(null),
      for (var i = 0; i < count; i++) swatch(i),
    ]);
  }
}

/// Hour / minute stepper with AM-PM, used for every exact alarm time.
/// Hours and minutes wheels for a length the preset row cannot express — the
/// presets stop at an hour and a half, this reaches twelve hours.
class DurationPicker extends StatefulWidget {
  final int minutes;
  final ValueChanged<int> onChanged;

  const DurationPicker({super.key, required this.minutes, required this.onChanged});

  static const int maxHours = 12;
  static const int minuteStep = 5;

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late FixedExtentScrollController _hours;
  late FixedExtentScrollController _mins;

  @override
  void initState() {
    super.initState();
    _hours = FixedExtentScrollController(initialItem: widget.minutes ~/ 60);
    _mins = FixedExtentScrollController(
        initialItem: (widget.minutes % 60) ~/ DurationPicker.minuteStep);
  }

  @override
  void didUpdateWidget(DurationPicker old) {
    super.didUpdateWidget(old);
    // A preset chip can change the length under us; follow it.
    if (widget.minutes == old.minutes) return;
    final h = widget.minutes ~/ 60;
    final m = (widget.minutes % 60) ~/ DurationPicker.minuteStep;
    if (_hours.selectedItem != h) _hours.jumpToItem(h);
    if (_mins.selectedItem != m) _mins.jumpToItem(m);
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _emit() {
    final total = _hours.selectedItem * 60 + _mins.selectedItem * DurationPicker.minuteStep;
    // Zero-length blocks would collapse on the timeline.
    widget.onChanged(total < DurationPicker.minuteStep ? DurationPicker.minuteStep : total);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);

    Widget wheel(FixedExtentScrollController controller, int count, String Function(int) label) =>
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (_) {
              HapticFeedback.selectionClick();
              _emit();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, i) => Center(
                child: Text(label(i),
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.txt)),
              ),
            ),
          ),
        );

    return Container(
      height: 168,
      decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(20)),
      child: Stack(children: [
        // The bar marking which row is selected sits under the wheels.
        Center(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(13)),
          ),
        ),
        Row(children: [
          wheel(_hours, DurationPicker.maxHours + 1, (i) => '$i'),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text('h', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt3)),
          ),
          wheel(_mins, 60 ~/ DurationPicker.minuteStep,
              (i) => (i * DurationPicker.minuteStep).toString().padLeft(2, '0')),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('m', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.txt3)),
          ),
        ]),
      ]),
    );
  }
}

class TimeStepper extends StatelessWidget {
  final int minutes;
  final bool use24;
  final ValueChanged<int> onChanged;

  /// How far one press of a minute arrow moves. Reminders and alarms use 1:
  /// an alarm for 6:52 has to be settable to 6:52.
  final int minuteStep;

  const TimeStepper({
    super.key,
    required this.minutes,
    required this.use24,
    required this.onChanged,
    this.minuteStep = 1,
  });

  /// The system clock dial, for typing a time in rather than stepping to it.
  Future<void> _type(BuildContext context) async {
    final c = AppScope.colorsOf(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (ctx, child) {
        final base = c.isDark ? ThemeData.dark() : ThemeData.light();
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use24),
          child: Theme(
            data: base.copyWith(
              colorScheme: base.colorScheme.copyWith(
                primary: c.acc,
                onPrimary: c.accTxt,
                surface: c.surf,
                onSurface: c.txt,
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final h24 = minutes ~/ 60;
    final hourText = use24 ? h24.toString().padLeft(2, '0') : ((h24 % 12 == 0) ? '12' : (h24 % 12).toString());
    final minText = (minutes % 60).toString().padLeft(2, '0');

    Widget stepper(String value, VoidCallback up, VoidCallback down) => Column(children: [
          _arrow(c, Icons.keyboard_arrow_up, up),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _type(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(value,
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, color: c.txt)),
            ),
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
            () => onChanged(((minutes ~/ minuteStep) * minuteStep + minuteStep) % 1440),
            () => onChanged((((minutes + minuteStep - 1) ~/ minuteStep) * minuteStep + 1440 - minuteStep) % 1440),
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
        const SizedBox(height: 6),
        Text('Tap the time to type it in', style: TextStyle(fontSize: 11.5, color: c.txt3)),
        const SizedBox(height: 12),
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

/// [tint] is the colour of the thing the icon is for. The picker shows every
/// icon in it, so what is chosen here looks the way it will on the timeline.
Future<String?> openIconPicker(BuildContext context, String current, {Color? tint}) {
  final store = AppScope.of(context);
  final base = AppColors.resolve(store.theme, store.accent);
  return Navigator.of(context).push<String>(MaterialPageRoute(
    fullscreenDialog: true,
    // A pushed page is built above the sheet that opened it, so it is handed
    // the colour rather than left to find it.
    builder: (_) => AppScope(
      store: store,
      colors: tint == null ? base : base.withAccent(tint),
      child: IconPicker(current: current),
    ),
  ));
}

class IconPicker extends StatefulWidget {
  final String current;
  const IconPicker({super.key, required this.current});

  @override
  State<IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<IconPicker> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The categories to show, each with the icons in it that match.
  List<MapEntry<String, List<String>>> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      // Searching looks everywhere: narrowing to a category first and then
      // finding nothing in it is the wrong way round.
      final seen = <String>{};
      final hits = [
        for (final e in kIconCategories.entries)
          for (final n in e.value)
            if ((iconWords(n).contains(q) || e.key.toLowerCase().contains(q)) && seen.add(n)) n,
      ];
      return [if (hits.isNotEmpty) MapEntry('${hits.length} found', hits)];
    }
    return [
      for (final e in kIconCategories.entries)
        if (_category == null || _category == e.key) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    final shown = _shown;

    Widget chip(String? category, String label) {
      final on = _category == category && _query.isEmpty;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? c.acc : c.surf,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              _category = category;
              _query = '';
              _search.clear();
            }),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? c.accTxt : c.txt2)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(children: [
              IconButton(
                tooltip: 'Back',
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
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        cursorColor: c.acc,
                        style: TextStyle(fontSize: 15, color: c.txt),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search ${kIcons.length} icons',
                          hintStyle: TextStyle(color: c.txt3),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _query = '';
                          _search.clear();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 18, color: c.txt3),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              children: [
                chip(null, 'All'),
                for (final name in kIconCategories.keys) chip(name, name),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text('Nothing called "$_query". Try a shorter word.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: c.txt2)),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      for (final entry in shown) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                          sliver: SliverToBoxAdapter(
                            child: Text(entry.key.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.txt3)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          sliver: SliverGrid.count(
                            crossAxisCount: 6,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                            children: [
                              for (final name in entry.value) _tile(c, name),
                            ],
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(AppColors c, String name) {
    final on = name == widget.current;
    return Semantics(
      button: true,
      selected: on,
      label: iconWords(name),
      child: Material(
        color: on ? c.acc : c.surf,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('icon-$name'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, name),
          child: Icon(iconFor(name), size: 23, color: on ? c.accTxt : c.acc),
        ),
      ),
    );
  }
}

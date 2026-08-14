import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons.dart';
import '../main.dart';
import '../models.dart';
import '../sheets.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String? _dragId;
  int _delta = 0;
  bool _overTrash = false;
  double _startY = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final layout = store.layout();
    final selected = store.selectedBlock;

    return Stack(children: [
      Column(children: [
        _header(store, c),
        Expanded(
          child: layout.rows.isEmpty
              ? _empty(store, c)
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, selected != null ? 280 : 150),
                  physics: _dragId == null
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(children: [
                    if (store.selectedIsToday && store.now < layout.origin) _aheadChip(store, c, layout),
                    SizedBox(
                      height: layout.trackHeight,
                      child: _track(store, c, layout),
                    ),
                  ]),
                ),
        ),
      ]),
      if (_dragId != null) _trashZone(c),
      if (selected != null && _dragId == null) _actionBar(store, c, selected),
    ]);
  }

  // ---------- header ----------

  Widget _header(Store store, AppColors c) {
    final days = store.weekDays;
    final first = days.first, last = days.last;
    final label = first.month == last.month
        ? '${monthShort(first.month)} ${first.day} – ${last.day}'
        : '${monthShort(first.month)} ${first.day} – ${monthShort(last.month)} ${last.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekdayName(store.selected),
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.txt)),
              const SizedBox(height: 3),
              Text(dayLabel(store, store.selected), style: TextStyle(fontSize: 13.5, color: c.txt2)),
            ]),
          ),
          _weekArrow(c, Icons.chevron_left, () => store.mutate(() => store.weekOffset--)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.txt2)),
          ),
          _weekArrow(c, Icons.chevron_right, () => store.mutate(() => store.weekOffset++)),
        ]),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final d in days)
              Expanded(
                child: GestureDetector(
                  onTap: () => store.mutate(() {
                    store.selected = d;
                    store.selectedBlockId = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: _dayChip(store, c, d),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _weekArrow(AppColors c, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.surf, shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: c.txt2),
        ),
      );

  Widget _dayChip(Store store, AppColors c, DateTime d) {
    final key = dateKey(d);
    final isSelected = key == store.selectedKey;
    final hasBlocks = store.blocks.any((b) => b.date == key);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? c.accTint : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: isSelected ? c.acc : c.txt3)),
        const SizedBox(height: 5),
        Text('${d.day}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isSelected ? c.acc : c.txt2)),
        const SizedBox(height: 5),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: hasBlocks ? (isSelected ? c.acc : c.txt3) : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ]),
    );
  }

  Widget _aheadChip(Store store, AppColors c, TimelineLayout layout) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: c.surf, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c.danger, shape: BoxShape.circle)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Now ${fmtMins(store.now, store.use24)} · first block at ${fmtMins(layout.first, store.use24)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.txt2),
            ),
          ),
        ]),
      );

  Widget _empty(Store store, AppColors c) => SingleChildScrollView(
        child: EmptyState(
          icon: Icons.event_available,
          title: 'Nothing planned',
          body: 'Add a block, or send something over from the Inbox.',
          action: Material(
            color: c.accTint,
            borderRadius: BorderRadius.circular(23),
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: () => store.resetDemo(),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                child: Row(children: [
                  Icon(Icons.auto_awesome, size: 19, color: c.acc),
                  const SizedBox(width: 8),
                  Text('Fill with an example day',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.acc)),
                ]),
              ),
            ),
          ),
        ),
      );

  // ---------- the track ----------

  Widget _track(Store store, AppColors c, TimelineLayout layout) {
    final children = <Widget>[
      // dotted rail
      Positioned(
        left: 83,
        top: 0,
        width: 5,
        height: layout.trackHeight,
        child: CustomPaint(painter: _RailPainter(color: c.node)),
      ),
    ];

    if (store.selectedIsToday && !store.classicTimeline) {
      final past = ((store.now - layout.origin) * layout.ppm).clamp(0, layout.trackHeight).toDouble();
      children.add(Positioned(
        left: 83,
        top: 0,
        width: 5,
        height: past,
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(3)),
        ),
      ));
    }

    for (final row in layout.rows) {
      children.add(_row(store, c, layout, row));
    }

    if (store.selectedIsToday && !store.classicTimeline && store.now >= layout.origin && store.now <= layout.last + 30) {
      children.add(Positioned(
        left: 79,
        right: 2,
        top: (store.now - layout.origin) * layout.ppm - 7,
        child: Row(children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: c.bg,
              shape: BoxShape.circle,
              border: Border.all(color: c.danger, width: 3),
            ),
          ),
          Expanded(child: Container(height: 2, color: c.danger.withOpacity(0.45))),
          Container(
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(10)),
            child: Text(fmtMins(store.now, store.use24),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c.onDanger)),
          ),
        ]),
      ));
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _row(Store store, AppColors c, TimelineLayout layout, LaidOutBlock row) {
    final b = row.block;
    final isDragged = _dragId == b.id;
    final isSelected = store.selectedBlockId == b.id;
    final live = store.selectedIsToday && b.start <= store.now && b.end > store.now;
    final palette = c.isDark ? kBlockColorsDark : kBlockColorsLight;
    final iconColor = store.blockColorIcons ? palette[b.color % palette.length] : c.acc;
    final shownStart = isDragged ? (b.start + _delta).clamp(0, 1440 - b.duration) : b.start;

    return Positioned(
      left: 0,
      right: 0,
      top: row.y + (isDragged ? _delta * layout.ppm : 0),
      height: row.height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 56,
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtMins(shownStart, store.use24),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: live ? FontWeight.w800 : FontWeight.w500,
                  color: live ? c.txt : c.txt2,
                )),
            Text(fmtMins(shownStart + b.duration, store.use24),
                textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: c.txt3)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => store.mutate(() => store.selectedBlockId = isSelected ? null : b.id),
            onLongPressStart: (d) {
              HapticFeedback.mediumImpact();
              setState(() {
                _dragId = b.id;
                _delta = 0;
                _overTrash = false;
                _startY = d.globalPosition.dy;
              });
            },
            onLongPressMoveUpdate: (d) {
              final dy = d.globalPosition.dy - _startY;
              final steps = (dy / layout.ppm / 5).round() * 5;
              final overTrash = d.globalPosition.dy > MediaQuery.of(context).size.height - 150;
              if (steps != _delta || overTrash != _overTrash) {
                setState(() {
                  _delta = steps;
                  _overTrash = overTrash;
                });
              }
            },
            onLongPressEnd: (_) {
              final id = _dragId;
              final delta = _delta;
              final trash = _overTrash;
              setState(() {
                _dragId = null;
                _delta = 0;
                _overTrash = false;
              });
              if (id == null) return;
              if (trash) {
                store.deleteBlock(id);
              } else if (delta != 0) {
                store.moveBlock(id, delta);
              }
            },
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: isSelected ? Border.all(color: c.acc, width: 2) : null,
                  boxShadow: isDragged
                      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 14))]
                      : null,
                ),
                child: Row(children: [
                  Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: live ? c.accTint : c.node,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(iconFor(b.icon), size: 24, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(
                          live ? '${b.end - store.now}m left · ${durLabel(b.duration)}' : durLabel(b.duration),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.txt3),
                        ),
                        if (row.overlaps) ...[
                          const SizedBox(width: 7),
                          Container(
                            height: 19,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Icon(Icons.merge, size: 13, color: c.acc),
                              const SizedBox(width: 4),
                              Text('OVERLAP',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.acc)),
                            ]),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.txt)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                ]),
              ),
              if (isDragged)
                Positioned(
                  left: 44,
                  top: -14,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _overTrash ? c.danger : c.acc,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Text(
                      _overTrash
                          ? 'Delete'
                          : '${_delta == 0 ? 'no change' : (_delta > 0 ? '+' : '−') + durLabel(_delta.abs())} → ${fmtMins(shownStart, store.use24)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _overTrash ? c.onDanger : c.accTxt,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------- drag furniture ----------

  Widget _trashZone(AppColors c) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 180,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.only(bottom: 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: _overTrash ? 76 : 62,
                height: _overTrash ? 76 : 62,
                decoration: BoxDecoration(color: _overTrash ? c.danger : c.surf2, shape: BoxShape.circle),
                child: Icon(Icons.delete, size: 30, color: _overTrash ? c.onDanger : c.txt2),
              ),
              const SizedBox(height: 10),
              Text(_overTrash ? 'Release to delete' : 'Drag to move · drop here to delete',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.txt)),
            ]),
          ),
        ),
      );

  // ---------- the action bar ----------

  Widget _actionBar(Store store, AppColors c, Block b) => Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Panel(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.txt)),
                  const SizedBox(height: 3),
                  Text(
                    '${fmtMins(b.start, store.use24)} – ${fmtMins(b.end, store.use24)} · ${durLabel(b.duration)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.acc),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: () => store.mutate(() => store.selectedBlockId = null),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: c.surf2, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 19, color: c.txt2),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _stepRow(c, 'MOVE', [
              ('−15', () => store.moveBlock(b.id, -15)),
              ('−5', () => store.moveBlock(b.id, -5)),
              ('+5', () => store.moveBlock(b.id, 5)),
              ('+15', () => store.moveBlock(b.id, 15)),
            ], accentMiddle: true),
            const SizedBox(height: 8),
            _stepRow(c, 'LAST', [
              ('−15', () => store.stretchBlock(b.id, -15)),
              ('−5', () => store.stretchBlock(b.id, -5)),
              ('+5', () => store.stretchBlock(b.id, 5)),
              ('+15', () => store.stretchBlock(b.id, 15)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Edit',
                  icon: Icons.edit,
                  onTap: () {
                    store.mutate(() => store.selectedBlockId = null);
                    openBlockSheet(context, existing: b);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: c.surf2,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => store.deleteBlock(b.id),
                  child: SizedBox(
                    width: 52,
                    height: 54,
                    child: Icon(Icons.delete, size: 19, color: c.danger),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _stepRow(AppColors c, String label, List<(String, VoidCallback)> steps, {bool accentMiddle = false}) {
    return Row(children: [
      SizedBox(
        width: 38,
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.txt3)),
      ),
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: accentMiddle && (i == 1 || i == 2) ? c.accTint : c.surf2,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: steps[i].$2,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(steps[i].$1,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: accentMiddle && (i == 1 || i == 2) ? c.acc : c.txt,
                    )),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// The dashed rail behind the blocks.
class _RailPainter extends CustomPainter {
  final Color color;
  _RailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(2.5, y), Offset(2.5, (y + 7).clamp(0, size.height)), paint);
      y += 13;
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) => old.color != color;
}

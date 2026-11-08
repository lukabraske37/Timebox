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

  /// Live state while the handle at the foot of a card is being pulled.
  String? _resizeId;
  int _resizeDelta = 0;
  double _resizePixels = 0;

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
                  physics: _dragId == null && _resizeId == null
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(children: [
                    if (store.selectedIsToday && store.now < layout.origin) _aheadChip(store, c, layout),
                    SizedBox(
                      height: layout.trackHeight,
                      child: LayoutBuilder(
                        builder: (_, box) => _track(store, c, layout, box.maxWidth),
                      ),
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
              _daySummary(store, c),
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

  /// A line under the date saying how the day stands, so its shape is legible
  /// before scrolling through it.
  Widget _daySummary(Store store, AppColors c) {
    final s = store.daySummary();
    if (s.count == 0) return const SizedBox.shrink();
    final parts = [
      '${s.count} ${s.count == 1 ? 'block' : 'blocks'}',
      '${durLabel(s.planned)} planned',
      if (s.free > 0) '${durLabel(s.free)} free',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(parts.join(' · '),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.txt3)),
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
          // This used to offer to fill the day with the example plan, which
          // replaces every block, task and habit the app holds — on any day
          // that happens to be empty. Resetting belongs in Settings; from here
          // the useful thing is to start planning this day.
          action: Material(
            color: c.accTint,
            borderRadius: BorderRadius.circular(23),
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onTap: () => openBlockSheet(context),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                child: Row(children: [
                  Icon(Icons.add_circle_outline, size: 19, color: c.acc),
                  const SizedBox(width: 8),
                  Text('Plan a block',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.acc)),
                ]),
              ),
            ),
          ),
        ),
      );

  // ---------- the track ----------

  Widget _track(Store store, AppColors c, TimelineLayout layout, double width) {
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

    // The rail goes solid for exactly as long as a block runs, so you can read
    // a block's span off the line itself. What stays dashed in between is the
    // free time. Filling the whole rail up to now, as this used to, flattened
    // both into one unbroken line.
    final palette = c.isDark ? kBlockColorsDark : kBlockColorsLight;
    for (final row in layout.rows) {
      children.add(Positioned(
        left: 83,
        top: row.y,
        width: 5,
        height: row.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: store.blockColorIcons ? palette[row.block.color % palette.length] : c.acc,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ));
    }

    final showNow = store.selectedIsToday &&
        !store.classicTimeline &&
        store.now >= layout.origin &&
        store.now <= layout.last + 30;
    final nowY = (store.now - layout.origin) * layout.ppm;
    final railAbove = children.length;

    for (final row in layout.rows) {
      children.add(_row(store, c, layout, row, width));
    }

    // Say how long each pause actually is, where the gap is tall enough to read.
    if (!store.classicTimeline) {
      for (var i = 1; i < layout.rows.length; i++) {
        final prev = layout.rows[i - 1];
        final next = layout.rows[i];
        final free = next.block.start - prev.block.end;
        final top = prev.y + prev.height;
        final gap = next.y - top;
        // Judge by the free time itself. Stretching a short block to stay
        // readable eats into the pixels after it, so a real pause can end up
        // with almost none left — say it anyway, as long as it can be read.
        if (free <= 0 || gap < 16) continue;
        children.add(Positioned(
          left: 96,
          right: 0,
          top: top,
          height: gap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Tapping empty time is the quickest way to plan into it: the sheet
            // opens already set to this slot, start and length both.
            onTap: () => openBlockSheet(context,
                startAt: prev.block.end, fill: free.clamp(5, 720)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${durLabel(free)} free',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.txt3)),
                if (gap >= 34) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.add_circle_outline, size: 13, color: c.txt3),
                ],
              ]),
            ),
          ),
        ));
      }
    }

    // The dot and the time stay on top, but the rule itself goes behind the
    // cards: drawn over them it cut whichever block was running in half.
    if (showNow) {
      children.insert(railAbove, Positioned(
        left: 86,
        right: 2,
        top: nowY - 1,
        height: 2,
        child: DecoratedBox(decoration: BoxDecoration(color: c.danger.withOpacity(0.45))),
      ));
      children.add(Positioned(
        left: 79,
        top: nowY - 6.5,
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: c.bg,
            shape: BoxShape.circle,
            border: Border.all(color: c.danger, width: 3),
          ),
        ),
      ));
      children.add(Positioned(
        right: 2,
        top: nowY - 9.5,
        child: Container(
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(10)),
          child: Text(fmtMins(store.now, store.use24),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c.onDanger)),
        ),
      ));
    }

    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _row(Store store, AppColors c, TimelineLayout layout, LaidOutBlock row, double width) {
    final b = row.block;
    final isDragged = _dragId == b.id;
    final isResized = _resizeId == b.id;
    final isSelected = store.selectedBlockId == b.id;
    final live = store.selectedIsToday && b.start <= store.now && b.end > store.now;
    final palette = c.isDark ? kBlockColorsDark : kBlockColorsLight;
    final iconColor = store.blockColorIcons ? palette[b.color % palette.length] : c.acc;
    final shownStart = isDragged ? (b.start + _delta).clamp(0, 1440 - b.duration) : b.start;
    final shownDur = isResized ? (b.duration + _resizeDelta).clamp(kStep, 1440) : b.duration;

    final tight = row.columns > 1;
    // A lone block keeps the old shape, its icon tile sitting over the rail.
    // Paired blocks have no tile to cover the rail, so they start clear of it
    // and each carries its own times — one set of stamps in the gutter could
    // only speak for one of them.
    final gutter = tight ? 96.0 : 72.0;
    final slot = (width - gutter) / row.columns;
    final cardLeft = gutter + row.column * slot;
    final cardWidth = slot - (tight ? 7 : 0);

    return Positioned(
      left: 0,
      width: width,
      top: row.y + (isDragged ? _delta * layout.ppm : 0),
      height: row.height + (isResized ? _resizeDelta * layout.ppm : 0),
      child: Stack(clipBehavior: Clip.none, children: [
        if (!tight)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 62,
            child: _stamps(store, c, shownStart, shownDur, live),
          ),
        Positioned(
          left: cardLeft,
          width: cardWidth,
          top: 0,
          bottom: 0,
          child: _oldRowBody(store, c, layout, row, b, isDragged, isResized, isSelected, live,
              iconColor, shownStart, shownDur, tight),
        ),
      ]),
    );
  }

  void _beginResize(Block b) {
    HapticFeedback.selectionClick();
    setState(() {
      _resizeId = b.id;
      _resizeDelta = 0;
      _resizePixels = 0;
    });
  }

  /// [pixels] is how far the finger has travelled since the pull began.
  void _resizeTo(Block b, TimelineLayout layout, double pixels) {
    final steps = (pixels / layout.ppm / kStep).round() * kStep;
    if (steps == _resizeDelta || b.duration + steps < kStep) return;
    HapticFeedback.selectionClick();
    setState(() => _resizeDelta = steps);
  }

  void _endResize(Store store) {
    final id = _resizeId;
    final delta = _resizeDelta;
    setState(() {
      _resizeId = null;
      _resizeDelta = 0;
      _resizePixels = 0;
    });
    if (id != null && delta != 0) store.stretchBlock(id, delta);
  }

  /// The start and end stamps in the left gutter.
  Widget _stamps(Store store, AppColors c, int shownStart, int shownDur, bool live) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fmtMins(shownStart, store.use24),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: live ? FontWeight.w800 : FontWeight.w500,
                color: live ? c.txt : c.txt2,
              )),
          Text(fmtMins(shownStart + shownDur, store.use24),
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(fontSize: 13.5, color: c.txt3)),
        ],
      );

  /// The card itself. [tight] is set when the block shares its slot with
  /// another, where the icon tile would crowd out the title.
  Widget _oldRowBody(
    Store store,
    AppColors c,
    TimelineLayout layout,
    LaidOutBlock row,
    Block b,
    bool isDragged,
    bool isResized,
    bool isSelected,
    bool live,
    Color iconColor,
    int shownStart,
    int shownDur,
    bool tight,
  ) {
    final roomy = row.columns == 1;
    final titleSize = roomy ? 19.0 : (row.columns == 2 ? 15.0 : 13.5);
    final metaSize = roomy ? 13.5 : 11.5;

    return GestureDetector(
      key: ValueKey('card-${b.id}'),
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
        final steps = (dy / layout.ppm / kStep).round() * kStep;
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
            color: store.blockColorIcons ? iconColor.withOpacity(c.isDark ? 0.13 : 0.10) : c.surf,
            borderRadius: BorderRadius.circular(roomy ? 28 : 20),
            border: isSelected ? Border.all(color: c.acc, width: 2) : null,
            boxShadow: isDragged || isResized
                ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 14))]
                : null,
          ),
          padding: EdgeInsets.fromLTRB(tight ? 12 : 0, 0, 6, 0),
          child: Row(children: [
            if (!tight) ...[
              Container(
                width: 62,
                height: 48,
                decoration: BoxDecoration(
                  color: live ? c.accTint : c.node,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(iconFor(b.icon), size: 28, color: iconColor),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          live
                              ? '${b.end - store.now}m left · ${durLabel(shownDur)}'
                              : durLabel(shownDur),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                              fontSize: metaSize, fontWeight: FontWeight.w600, color: c.txt3),
                        ),
                      ),
                      if (row.overlaps && roomy) ...[
                        const SizedBox(width: 7),
                        Container(
                          height: 19,
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          decoration:
                              BoxDecoration(color: c.accTint, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Icon(Icons.merge, size: 13, color: c.acc),
                            const SizedBox(width: 4),
                            Text('OVERLAP',
                                style: TextStyle(
                                    fontSize: 10.5, fontWeight: FontWeight.w700, color: c.acc)),
                          ]),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(b.title,
                        // A block pinned to the minimum height only has room for
                        // the duration line plus a single title line; a second
                        // one would spill out of the card.
                        maxLines: row.height >= 100 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: c.txt)),
                    if (tight) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${fmtMins(shownStart, store.use24)} – ${fmtMins(shownStart + shownDur, store.use24)}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(fontSize: 11, color: c.txt3),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),

        // Pull this to change how long the block runs, in five minute steps.
        // Only the nub itself takes the drag: spanning the card's whole width
        // meant any scroll begun near the foot of a card resized it instead of
        // moving the day, and sitting below the card put part of it out of
        // reach, since a Stack does not hit-test past its own bounds.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 32,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Both gesture families drive the same resize. A quick pull
              // arrives as a drag; resting on the handle first turns it into a
              // long press, which the card would otherwise claim — and then
              // the block moved instead of growing.
              onVerticalDragStart: (_) => _beginResize(b),
              onVerticalDragUpdate: (d) {
                _resizePixels += d.primaryDelta ?? 0;
                _resizeTo(b, layout, _resizePixels);
              },
              onVerticalDragEnd: (_) => _endResize(store),
              onLongPressStart: (_) => _beginResize(b),
              onLongPressMoveUpdate: (d) => _resizeTo(b, layout, d.offsetFromOrigin.dy),
              onLongPressEnd: (_) => _endResize(store),
              child: SizedBox(
                key: ValueKey('resize-${b.id}'),
                // Comfortably larger than the nub it draws: the card grows
                // under the finger while resizing, so the handle has moved by
                // the time you reach for it again.
                width: 112,
                height: 32,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isResized ? c.acc : c.txt3.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        if (isResized)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(12)),
              child: Text(durLabel(shownDur),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.accTxt)),
            ),
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))
                ],
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

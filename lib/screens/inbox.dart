import 'package:flutter/material.dart';

import '../icons.dart';
import '../main.dart';
import '../models.dart';
import '../sheets.dart';
import '../ui.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = AppScope.colorsOf(context);
    final count = store.inbox.length;

    return Column(children: [
      ScreenTitle(
        title: 'Inbox',
        subtitle: count == 0
            ? 'Nothing saved yet'
            : '$count saved ${count == 1 ? 'block' : 'blocks'} · Add as often as you like',
      ),
      Expanded(
        child: count == 0
            ? SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.inbox,
                  title: 'Your Unstructured Thoughts',
                  body: 'Save the blocks you plan again and again — walk the dog, gym, school run. '
                      'Then drop one onto any day with a single tap.',
                  action: Material(
                    color: c.accTint,
                    borderRadius: BorderRadius.circular(25),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: () => openInboxSheet(context),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        alignment: Alignment.center,
                        child: Row(children: [
                          Icon(Icons.add_circle_outline, size: 20, color: c.acc),
                          const SizedBox(width: 8),
                          Text('New Inbox Task',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.acc)),
                        ]),
                      ),
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                itemCount: count,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final item = store.inbox[i];
                  return Panel(
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(14)),
                        child: Icon(iconFor(item.icon), size: 22, color: c.acc),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(durLabel(item.dur),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.txt3)),
                          const SizedBox(height: 2),
                          Text(item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.txt)),
                        ]),
                      ),
                      GestureDetector(
                        onTap: () => openInboxSheet(context, existing: item),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.edit, size: 18, color: c.txt3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Material(
                        color: c.accTint,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            final b = store.scheduleFromInbox(item);
                            showToast(
                              context,
                              '${item.title} → ${weekdayName(store.selected).substring(0, 3)} '
                              '${store.selected.day}, ${fmtMins(b.start, store.use24)}',
                            );
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            child: Row(children: [
                              Icon(Icons.add, size: 21, color: c.acc),
                              const SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.acc)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

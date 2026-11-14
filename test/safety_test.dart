import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timebox/models.dart';
import 'package:timebox/services.dart';
import 'package:timebox/store.dart';

/// The promises the app makes about not losing what you put in it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Store> open([Map<String, Object> disk = const {}]) async {
    SharedPreferences.setMockInitialValues(disk);
    final store = Store(notifications: false);
    await store.load();
    addTearDown(store.dispose);
    return store;
  }

  String stateWith(String title) {
    final s = Store(notifications: false)
      ..booted = true
      ..tasks = [Task(id: 't', title: title)];
    final raw = jsonEncode(s.toJson());
    s.dispose();
    return raw;
  }

  test('a save that cannot be read is kept, and the last good copy is used', () async {
    final store = await open({
      'timebox.state': '{"blocks": [oops',
      'timebox.state.bak': stateWith('From the good copy'),
    });
    expect(store.tasks.single.title, 'From the good copy');
    expect(store.loadNotice, isNotNull, reason: 'falling back a copy should not happen silently');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('timebox.state.corrupt'), '{"blocks": [oops',
        reason: 'what could not be read must be parked, never overwritten');
  });

  test('with no good copy at all the unreadable save still survives', () async {
    final store = await open({'timebox.state': 'not json'});
    expect(store.tasks, isEmpty, reason: 'demo data must not be passed off as yours');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('timebox.state.corrupt'), 'not json');
  });

  test('one broken entry does not take the rest of the list with it', () async {
    final store = await open({
      'timebox.state': jsonEncode({
        'booted': true,
        'tasks': [
          {'id': 'a', 'title': 'Fine'},
          'garbage',
          {'title': 'No id'},
          {'id': 'b', 'title': 'Also fine'},
        ],
      }),
    });
    expect(store.tasks.map((t) => t.title), ['Fine', 'Also fine']);
  });

  test('deleting everything leaves it empty rather than bringing the demo back', () async {
    final first = await open();
    first.mutate(() {
      first.booted = true;
      first.blocks.clear();
      first.tasks.clear();
      first.habits.clear();
      first.inbox.clear();
    });
    first.flush();

    final prefs = await SharedPreferences.getInstance();
    final again = Store(notifications: false);
    addTearDown(again.dispose);
    SharedPreferences.setMockInitialValues({'timebox.state': prefs.getString('timebox.state')!});
    await again.load();
    expect(again.blocks, isEmpty);
    expect(again.tasks, isEmpty);
  });

  test('leaving the app writes what the save timer was still holding', () async {
    final store = await open();
    store.addTask(Task(id: 'late', title: 'Typed a moment before leaving'));
    store.leftApp();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('timebox.state'), contains('Typed a moment before leaving'));
  });

  test('a delete can be undone', () async {
    final store = await open();
    String? offered;
    store.onUndoable = (label) => offered = label;
    final before = store.tasks.length;
    store.deleteTask(store.tasks.first.id);
    expect(store.tasks.length, before - 1);
    expect(offered, 'Task deleted');
    store.undo();
    expect(store.tasks.length, before);
  });

  test('a restore keeps what it replaced, and refuses a file that is not a backup', () async {
    final store = await open();
    final mine = store.tasks.length;

    expect(await store.restore({'name': 'package.json', 'version': '1.0.0'}), isFalse);
    expect(store.tasks.length, mine, reason: 'a wrong file must change nothing');

    expect(await store.restore(jsonDecode(stateWith('From the file')) as Map<String, dynamic>), isTrue);
    expect(store.tasks.single.title, 'From the file');

    final kept = store.snapshots().firstWhere((s) => s.isBeforeRestore);
    expect(kept.tasks, mine);
    expect(await store.restoreSnapshot(kept.id), isTrue);
    expect(store.tasks.length, mine, reason: 'restoring the wrong file can itself be undone');
  });

  test('a restored file cannot switch this phone\'s lock off', () async {
    final store = await open();
    store.biometric = true;
    await store.restore(jsonDecode(stateWith('x')) as Map<String, dynamic>);
    expect(store.biometric, isTrue);
  });

  test('only the last week of daily copies is kept', () async {
    final disk = <String, Object>{'timebox.state': stateWith('today')};
    for (var d = 1; d <= 12; d++) {
      final key = dateKey(DateTime.now().subtract(Duration(days: d)));
      disk['timebox.snap.$key'] = stateWith('day $d');
    }
    final store = await open(disk);
    final snaps = store.snapshots();
    expect(snaps.length, kSnapshotsKept);
    expect(snaps.first.id, todayKey(), reason: 'opening the app takes today\'s copy');
  });

  test('the backup reader tells a backup from any other file', () {
    expect(Backup.parse(stateWith('ok')).data, isNotNull);
    expect(Backup.parse('{"hello": "world"}').error, isNotNull);
    expect(Backup.parse('<html>').error, isNotNull);
    expect(Backup.parse('{"blocks": "many"}').error, isNotNull);
  });
}

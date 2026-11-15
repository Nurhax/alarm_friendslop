import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Kontrak data. Sekarang implementasinya SQLite lokal.
/// Nanti tinggal bikin implementasi Firebase/Supabase/REST tanpa ubah UI.
abstract class AlarmRepository {
  Future<List<Room>> rooms();
  Future<Room?> roomByCode(String code);
  Future<Room> createRoom(String name);
  Future<void> renameRoom(Room room, String name);
  Future<void> deleteRoom(Room room);

  Future<List<AlarmItem>> alarms(int roomId);
  Future<List<AlarmItem>> allAlarms();
  Future<AlarmItem> saveAlarm(AlarmItem alarm); // insert kalau id null, else update
  Future<void> deleteAlarm(int id);
}

class SqliteAlarmRepository implements AlarmRepository {
  SqliteAlarmRepository._(this._db);
  final Database _db;

  static Future<SqliteAlarmRepository> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'alarm_bareng.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE rooms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE alarms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id INTEGER NOT NULL REFERENCES rooms(id),
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            label TEXT NOT NULL DEFAULT '',
            enabled INTEGER NOT NULL DEFAULT 1,
            days TEXT NOT NULL DEFAULT '',
            once_at INTEGER
          )''');
      },
    );
    return SqliteAlarmRepository._(db);
  }

  @override
  Future<List<Room>> rooms() async =>
      (await _db.query('rooms', orderBy: 'id DESC')).map(Room.fromMap).toList();

  @override
  Future<Room?> roomByCode(String code) async {
    final rows =
        await _db.query('rooms', where: 'code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : Room.fromMap(rows.first);
  }

  @override
  Future<Room> createRoom(String name) async {
    final room = Room(code: Room.newCode(), name: name);
    final id = await _db.insert('rooms', room.toMap());
    return Room(id: id, code: room.code, name: name);
  }

  @override
  Future<void> renameRoom(Room room, String name) async {
    await _db.update('rooms', {'name': name},
        where: 'id = ?', whereArgs: [room.id]);
  }

  @override
  Future<void> deleteRoom(Room room) async {
    await _db.transaction((t) async {
      await t.delete('alarms', where: 'room_id = ?', whereArgs: [room.id]);
      await t.delete('rooms', where: 'id = ?', whereArgs: [room.id]);
    });
  }

  @override
  Future<List<AlarmItem>> alarms(int roomId) async => (await _db.query('alarms',
          where: 'room_id = ?', whereArgs: [roomId], orderBy: 'hour, minute'))
      .map(AlarmItem.fromMap)
      .toList();

  @override
  Future<List<AlarmItem>> allAlarms() async =>
      (await _db.query('alarms', orderBy: 'hour, minute'))
          .map(AlarmItem.fromMap)
          .toList();

  @override
  Future<AlarmItem> saveAlarm(AlarmItem a) async {
    if (a.id == null) {
      final id = await _db.insert('alarms', a.toMap());
      return a.copyWith(id: id);
    }
    await _db.update('alarms', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    return a;
  }

  @override
  Future<void> deleteAlarm(int id) async {
    await _db.delete('alarms', where: 'id = ?', whereArgs: [id]);
  }
}
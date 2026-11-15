import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../datamodels/data.dart';
import '../datamodels/models.dart';

/// Di-set di main(). Dipakai UI untuk semua operasi CRUD.
late AlarmService alarmService;

/// Satu-satunya tempat yang tahu cara "membunyikan" alarm.
/// Bunyi/tidaknya murni berdasarkan jam device (OS yang trigger).
/// Kalau nanti mau layar alarm custom, ganti isi class ini saja.
class AlarmService {
  AlarmService(this.repo);
  final AlarmRepository repo;
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()));

    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await syncAll();
  }

  // ---------- API untuk UI ----------

  Future<AlarmItem> save(AlarmItem a) async {
    // jam/hari/enabled berubah -> jadwal "sekali" dihitung ulang
    final saved = await repo.saveAlarm(a.copyWith(clearOnceAt: true));
    await _syncAlarm(saved);
    return saved;
  }

  Future<void> delete(AlarmItem a) async {
    await _cancel(a.id!);
    await repo.deleteAlarm(a.id!);
  }

  Future<void> deleteRoom(Room room) async {
    for (final a in await repo.alarms(room.id!)) {
      await _cancel(a.id!);
    }
    await repo.deleteRoom(room);
  }

  /// Panggil saat app start (dan nanti setiap data hasil sync berubah).
  Future<void> syncAll() async {
    for (final a in await repo.allAlarms()) {
      await _syncAlarm(a);
    }
  }

  // ---------- internal ----------

  int _nid(int alarmId, int day) => alarmId * 10 + day; // day 0 = sekali

  Future<void> _cancel(int alarmId) async {
    for (var d = 0; d <= 7; d++) {
      await _plugin.cancel(_nid(alarmId, d));
    }
  }

  tz.TZDateTime _next(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (!t.isAfter(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  Future<void> _syncAlarm(AlarmItem a) async {
    final id = a.id!;
    await _cancel(id);
    if (!a.enabled) return;

    if (a.days.isEmpty) {
      // alarm sekali
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (a.onceAt != null && a.onceAt! <= nowMs) {
        // sudah lewat -> matikan otomatis
        await repo.saveAlarm(a.copyWith(enabled: false, clearOnceAt: true));
        return;
      }
      final when = a.onceAt != null
          ? tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, a.onceAt!)
          : _next(a.hour, a.minute);
      if (a.onceAt == null) {
        await repo.saveAlarm(a.copyWith(onceAt: when.millisecondsSinceEpoch));
      }
      await _schedule(a, _nid(id, 0), when, null);
    } else {
      // berulang mingguan: satu jadwal per hari terpilih
      for (final d in a.days) {
        await _schedule(a, _nid(id, d), _next(a.hour, a.minute, weekday: d),
            DateTimeComponents.dayOfWeekAndTime);
      }
    }
  }

  Future<void> _schedule(AlarmItem a, int notifId, tz.TZDateTime when,
      DateTimeComponents? repeat) {
    return _plugin.zonedSchedule(
      notifId,
      a.label.isEmpty ? 'Alarm' : a.label,
      a.timeText,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      matchDateTimeComponents: repeat,
    );
  }

  NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm',
          channelDescription: 'Notifikasi alarm',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          enableVibration: true,
          // FLAG_INSISTENT: suara berulang sampai notifikasi di-dismiss
          additionalFlags: Int32List.fromList(<int>[4]),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
}
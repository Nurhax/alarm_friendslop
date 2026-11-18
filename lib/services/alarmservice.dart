import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data_models/data.dart';
import '../data_models/models.dart';
import 'mediacache.dart';

/// Di-set di main(). Dipakai UI untuk semua operasi CRUD.
late AlarmService alarmService;

/// Satu-satunya tempat yang tahu cara "membunyikan" alarm.
/// Bunyi/tidaknya murni berdasarkan jam device (OS yang trigger).
///
/// Package `alarm` tidak punya fitur repeat, jadi alarm berulang dijadwalkan
/// sebagai beberapa alarm tunggal untuk [horizonDays] hari ke depan, dan
/// dijadwalkan ulang (diisi lagi) setiap app dibuka.
///
/// ID alarm di plugin = idDb * 100 + slot
///   - alarm sekali  : slot 0
///   - alarm berulang: slot = offset hari dari hari ini (0..27)
class AlarmService {
  AlarmService(this.repo);
  final AlarmRepository repo;

  static const horizonDays = 28;
  static const _testId = 2000000000;

  Future<void> init() async {
    await Alarm.init();
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    await syncAll();
  }

  // ---------- API untuk UI ----------

  /// Simpan alarm lalu jadwalkan. Mengembalikan pesan peringatan kalau
  /// gambar/suara gagal diunduh (alarm tetap dijadwalkan dengan suara default).
  Future<String?> save(AlarmItem a) async {
    // jam/hari/enabled berubah -> jadwal "sekali" dihitung ulang
    final saved = await repo.saveAlarm(a.copyWith(clearOnceAt: true));
    return _syncAlarm(saved);
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

  /// Alarm uji: bunyi [delay] lagi dengan gambar/suara dari URL.
  /// Dipakai untuk menguji ring screen tanpa nunggu jam alarm sungguhan.
  Future<String?> debugRing({
    Duration delay = const Duration(seconds: 30),
    String imageUrl = '',
    String audioUrl = '',
    String label = 'Tes alarm',
  }) async {
    final m = await _prepareMedia(imageUrl, audioUrl);
    await Alarm.set(
      alarmSettings: _settings(
        id: _testId,
        when: DateTime.now().add(delay),
        title: label,
        audioPath: m.audio,
        imagePath: m.image,
      ),
    );
    return m.warning;
  }

  // ---------- internal ----------

  Future<String?> _syncAlarm(AlarmItem a) async {
    final id = a.id!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (!a.enabled) {
      await _cancel(id);
      return null;
    }

    // alarm sekali yang waktunya sudah lewat -> matikan (jangan dijadwal ulang)
    if (a.days.isEmpty && a.onceAt != null && a.onceAt! <= nowMs) {
      await repo.saveAlarm(a.copyWith(enabled: false, clearOnceAt: true));
      return null;
    }

    // unduh media dulu (bisa lama), baru ganti jadwal
    final m = await _prepareMedia(a.imageUrl, a.audioUrl);

    final slots = <(int, DateTime)>[];
    if (a.days.isEmpty) {
      final when = a.onceAt != null
          ? DateTime.fromMillisecondsSinceEpoch(a.onceAt!)
          : _nextOnce(a.hour, a.minute);
      if (a.onceAt == null) {
        await repo.saveAlarm(a.copyWith(onceAt: when.millisecondsSinceEpoch));
      }
      slots.add((0, when));
    } else {
      final now = DateTime.now();
      for (var i = 0; i < horizonDays; i++) {
        final d = DateTime(now.year, now.month, now.day + i, a.hour, a.minute);
        if (a.days.contains(d.weekday) && d.isAfter(now)) slots.add((i, d));
      }
    }

    await _cancel(id);
    final title = a.label.isEmpty ? 'Alarm' : a.label;
    for (final (slot, ringAt) in slots) {
      await Alarm.set(
        alarmSettings: _settings(
          id: id * 100 + slot,
          when: ringAt,
          title: title,
          audioPath: m.audio,
          imagePath: m.image,
        ),
      );
    }
    return m.warning;
  }

  DateTime _nextOnce(int hour, int minute) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Batalkan semua jadwal milik satu alarm DB.
  /// Alarm yang SEDANG berbunyi tidak disentuh (penting: syncAll jalan saat
  /// app dibuka oleh full-screen intent dan tidak boleh mematikan bunyinya).
  Future<void> _cancel(int dbId) async {
    for (final s in await Alarm.getAlarms()) {
      if (s.id ~/ 100 != dbId) continue;
      if (await Alarm.isRinging(s.id)) continue;
      await Alarm.stop(s.id);
    }
  }

  Future<({String? image, String? audio, String? warning})> _prepareMedia(
      String imageUrl, String audioUrl) async {
    String? image, audio;
    final warnings = <String>[];
    if (imageUrl.trim().isNotEmpty) {
      try {
        image = await MediaCache.fetch(imageUrl, MediaKind.image);
      } catch (e) {
        warnings.add('Gambar gagal: $e');
      }
    }
    if (audioUrl.trim().isNotEmpty) {
      try {
        audio = await MediaCache.fetch(audioUrl, MediaKind.audio);
      } catch (e) {
        warnings.add('Suara gagal: $e');
      }
    }
    return (
      image: image,
      audio: audio,
      warning: warnings.isEmpty ? null : warnings.join('\n'),
    );
  }

  AlarmSettings _settings({
    required int id,
    required DateTime when,
    required String title,
    String? audioPath, // null = suara alarm default device
    String? imagePath,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: when,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: false,
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      // dua alarm di menit yang sama (beda room) harus tetap bunyi dua-duanya
      allowSameSecondScheduling: true,
      // dibaca ring screen, jadi tidak perlu query DB saat alarm bunyi
      payload: jsonEncode({'img': imagePath, 'title': title}),
      volumeSettings: VolumeSettings.fixed(volume: 0.8),
      notificationSettings: NotificationSettings(
        title: title,
        body: 'Alarm Bareng',
        // Sementara ada tombol stop supaya tes tidak "terjebak".
        // Nanti dihapus supaya mematikan alarm harus lewat check-in.
        stopButton: 'Matikan',
      ),
    );
  }
}
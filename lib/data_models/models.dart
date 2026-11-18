import 'dart:math';

/// Index = weekday - 1 (DateTime.monday = 1 ... DateTime.sunday = 7)
const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// "Room" = unit yang dishare. Isinya kumpulan alarm.
class Room {
  final int? id;
  final String code; // kode share, dipakai di link
  final String name;

  const Room({this.id, required this.code, required this.name});

  Room copyWith({String? name}) =>
      Room(id: id, code: code, name: name ?? this.name);

  Map<String, Object?> toMap() => {'id': id, 'code': code, 'name': name};

  factory Room.fromMap(Map<String, Object?> m) => Room(
        id: m['id'] as int,
        code: m['code'] as String,
        name: m['name'] as String,
      );

  /// Ganti domain ini kalau nanti sudah ada deep link / web.
  String get shareLink => 'https://alarmbareng.example/r/$code';

  static String newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

class AlarmItem {
  final int? id;
  final int roomId;
  final int hour;
  final int minute;
  final String label;
  final bool enabled;

  /// 1 = Senin ... 7 = Minggu. Kosong = alarm sekali bunyi.
  final Set<int> days;

  /// Khusus alarm sekali: waktu bunyi (epoch ms) yang sudah dijadwalkan.
  final int? onceAt;

  /// URL gambar pop-up & URL suara alarm ('' = tidak ada, pakai default).
  final String imageUrl;
  final String audioUrl;

  const AlarmItem({
    this.id,
    required this.roomId,
    required this.hour,
    required this.minute,
    this.label = '',
    this.enabled = true,
    this.days = const {},
    this.onceAt,
    this.imageUrl = '',
    this.audioUrl = '',
  });

  AlarmItem copyWith({
    int? id,
    int? hour,
    int? minute,
    String? label,
    bool? enabled,
    Set<int>? days,
    int? onceAt,
    bool clearOnceAt = false,
    String? imageUrl,
    String? audioUrl,
  }) =>
      AlarmItem(
        id: id ?? this.id,
        roomId: roomId,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
        days: days ?? this.days,
        onceAt: clearOnceAt ? null : (onceAt ?? this.onceAt),
        imageUrl: imageUrl ?? this.imageUrl,
        audioUrl: audioUrl ?? this.audioUrl,
      );

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get daysText {
    if (days.isEmpty) return 'Sekali';
    if (days.length == 7) return 'Setiap hari';
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayNames[d - 1]).join(', ');
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'room_id': roomId,
        'hour': hour,
        'minute': minute,
        'label': label,
        'enabled': enabled ? 1 : 0,
        'days': (days.toList()..sort()).join(','),
        'once_at': onceAt,
        'image_url': imageUrl,
        'audio_url': audioUrl,
      };

  factory AlarmItem.fromMap(Map<String, Object?> m) {
    final d = m['days'] as String;
    return AlarmItem(
      id: m['id'] as int,
      roomId: m['room_id'] as int,
      hour: m['hour'] as int,
      minute: m['minute'] as int,
      label: m['label'] as String,
      enabled: (m['enabled'] as int) == 1,
      days: d.isEmpty ? <int>{} : d.split(',').map(int.parse).toSet(),
      onceAt: m['once_at'] as int?,
      imageUrl: (m['image_url'] as String?) ?? '',
      audioUrl: (m['audio_url'] as String?) ?? '',
    );
  }
}
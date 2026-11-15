import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';


import '../services/alarmService.dart';
import '../datamodels/models.dart';

// ---------- helper dialog ----------

Future<String?> askText(BuildContext context, String title,
    {String initial = '', String hint = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String text) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya')),
      ],
    ),
  );
  return r ?? false;
}

// ---------- 1. daftar room ----------

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  List<Room> _rooms = [];
  Map<int, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rooms = await alarmService.repo.rooms();
    final all = await alarmService.repo.allAlarms();
    final counts = <int, int>{};
    for (final a in all) {
      counts[a.roomId] = (counts[a.roomId] ?? 0) + 1;
    }
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _counts = counts;
    });
  }

  Future<void> _create() async {
    final name = await askText(context, 'Nama room', hint: 'mis. Alarm Kos');
    if (name == null || name.isEmpty) return;
    final room = await alarmService.repo.createRoom(name);
    if (!mounted) return;
    await _open(room);
  }

  Future<void> _join() async {
    final input = await askText(context, 'Kode / link room');
    if (input == null || input.isEmpty) return;
    final code = input.split('/').last.trim().toUpperCase();
    final room = await alarmService.repo.roomByCode(code);
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Room tidak ditemukan. DB masih lokal, belum ada sync antar device.')));
      return;
    }
    await _open(room);
  }

  Future<void> _open(Room room) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Bareng'),
        actions: [
          IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Gabung pakai kode',
              onPressed: _join),
        ],
      ),
      body: _rooms.isEmpty
          ? const Center(child: Text('Belum ada room. Buat dulu!'))
          : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (_, i) {
                final r = _rooms[i];
                return ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(r.name),
                  subtitle:
                      Text('Kode: ${r.code} • ${_counts[r.id] ?? 0} alarm'),
                  onTap: () => _open(r),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Buat room'),
      ),
    );
  }
}

// ---------- 2. isi room (list alarm + CRUD) ----------

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late Room _room = widget.room;
  List<AlarmItem> _alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await alarmService.repo.alarms(_room.id!);
    if (!mounted) return;
    setState(() => _alarms = list);
  }

  Future<void> _edit([AlarmItem? a]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AlarmEditScreen(roomId: _room.id!, alarm: a)));
    _load();
  }

  void _share() {
    Share.share('Gabung room alarm "${_room.name}"\n'
        'Kode: ${_room.code}\n'
        'Link: ${_room.shareLink}');
  }

  Future<void> _onMenu(String v) async {
    if (v == 'rename') {
      final name = await askText(context, 'Ganti nama room', initial: _room.name);
      if (name == null || name.isEmpty) return;
      await alarmService.repo.renameRoom(_room, name);
      if (!mounted) return;
      setState(() => _room = _room.copyWith(name: name));
    } else if (v == 'delete') {
      if (!await confirm(context, 'Hapus room dan semua alarmnya?')) return;
      await alarmService.deleteRoom(_room);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_room.name),
        actions: [
          IconButton(
              icon: const Icon(Icons.share), tooltip: 'Share', onPressed: _share),
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Ganti nama')),
              PopupMenuItem(value: 'delete', child: Text('Hapus room')),
            ],
          ),
        ],
      ),
      body: _alarms.isEmpty
          ? const Center(child: Text('Belum ada alarm di room ini.'))
          : ListView.builder(
              itemCount: _alarms.length,
              itemBuilder: (_, i) {
                final a = _alarms[i];
                return Dismissible(
                  key: ValueKey(a.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    setState(() => _alarms.remove(a));
                    await alarmService.delete(a);
                  },
                  child: ListTile(
                    onTap: () => _edit(a),
                    leading: Text(a.timeText,
                        style: Theme.of(context).textTheme.headlineMedium),
                    title: Text(a.label.isEmpty ? 'Alarm' : a.label),
                    subtitle: Text(a.daysText),
                    trailing: Switch(
                      value: a.enabled,
                      onChanged: (v) async {
                        await alarmService.save(a.copyWith(enabled: v));
                        _load();
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------- 3. tambah / edit alarm ----------

class AlarmEditScreen extends StatefulWidget {
  final int roomId;
  final AlarmItem? alarm; // null = alarm baru
  const AlarmEditScreen({super.key, required this.roomId, this.alarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late TimeOfDay _time = widget.alarm != null
      ? TimeOfDay(hour: widget.alarm!.hour, minute: widget.alarm!.minute)
      : TimeOfDay.now();
  late final _label = TextEditingController(text: widget.alarm?.label ?? '');
  late final Set<int> _days = Set.of(widget.alarm?.days ?? <int>{});

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    await alarmService.save(AlarmItem(
      id: widget.alarm?.id,
      roomId: widget.roomId,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim(),
      enabled: true,
      days: Set.of(_days),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'Alarm baru' : 'Edit alarm'),
        actions: [TextButton(onPressed: _save, child: const Text('Simpan'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _pickTime,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('$hh:$mm',
                    style: Theme.of(context).textTheme.displayLarge),
              ),
            ),
          ),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label (opsional)'),
          ),
          const SizedBox(height: 24),
          const Text('Ulangi (kosongkan = sekali saja)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(dayNames[d - 1]),
                  selected: _days.contains(d),
                  onSelected: (s) =>
                      setState(() => s ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
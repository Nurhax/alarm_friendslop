import 'package:flutter/material.dart';

import '../data_models/models.dart';
import '../services/alarmservice.dart';

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
  late final _image = TextEditingController(text: widget.alarm?.imageUrl ?? '');
  late final _audio = TextEditingController(text: widget.alarm?.audioUrl ?? '');
  late final Set<int> _days = Set.of(widget.alarm?.days ?? <int>{});
  bool _busy = false;

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 6)));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final warning = await alarmService.save(AlarmItem(
      id: widget.alarm?.id,
      roomId: widget.roomId,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim(),
      enabled: true,
      days: Set.of(_days),
      imageUrl: _image.text.trim(),
      audioUrl: _audio.text.trim(),
    ));
    if (!mounted) return;
    if (warning != null) _snack('$warning\nAlarm tetap aktif dengan default.');
    Navigator.pop(context);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final warning = await alarmService.debugRing(
      imageUrl: _image.text.trim(),
      audioUrl: _audio.text.trim(),
      label: _label.text.trim().isEmpty ? 'Tes alarm' : _label.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(warning ??
        'Alarm uji bunyi 30 detik lagi. Kunci layar / swipe app dari recents sekarang.');
  }

  @override
  void dispose() {
    _label.dispose();
    _image.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'Alarm baru' : 'Edit alarm'),
        actions: [
          TextButton(
              onPressed: _busy ? null : _save, child: const Text('Simpan')),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
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
          const SizedBox(height: 16),
          TextField(
            controller: _image,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'URL gambar pop-up (https, maks 5 MB)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _audio,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'URL suara (https, maks 5 MB)'),
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
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _busy ? null : _test,
            icon: const Icon(Icons.bug_report),
            label: const Text('Tes bunyi 30 detik lagi'),
          ),
        ],
      ),
    );
  }
}
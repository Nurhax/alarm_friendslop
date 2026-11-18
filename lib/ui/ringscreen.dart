import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

/// Layar penuh saat alarm bunyi: foto tanpa teks + tombol check-in.
/// Menutup dengan hasil [Duration] = selisih dari jam alarm sampai check-in
/// (nanti jadi dasar ranking).
class RingScreen extends StatelessWidget {
  const RingScreen({super.key, required this.alarm});
  final AlarmSettings alarm;

  String? get _imagePath {
    try {
      final m = jsonDecode(alarm.payload ?? '{}') as Map<String, dynamic>;
      return m['img'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkIn(BuildContext context) async {
    final delta = DateTime.now().difference(alarm.dateTime);
    Navigator.pop(context, delta); // pop dulu, baru stop (hindari race)
    await Alarm.stop(alarm.id);
  }

  @override
  Widget build(BuildContext context) {
    final img = _imagePath;
    final hasImage = img != null && File(img).existsSync();

    return PopScope(
      canPop: false, // tidak bisa kabur pakai tombol back
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(File(img), fit: BoxFit.cover)
            else
              const ColoredBox(
                color: Colors.deepPurple,
                child: Center(
                  child: Icon(Icons.alarm, size: 120, color: Colors.white),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FilledButton(
                    onPressed: () => _checkIn(context),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Text('CHECK-IN'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
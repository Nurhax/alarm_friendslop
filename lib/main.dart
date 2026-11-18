import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/material.dart';

import '../data_models/data.dart';
import 'services/alarmservice.dart';
import 'ui/ringscreen.dart';
import 'ui/ui.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  alarmService = AlarmService(await SqliteAlarmRepository.open());
  await alarmService.init();
  runApp(const AlarmBarengApp());
}

class AlarmBarengApp extends StatefulWidget {
  const AlarmBarengApp({super.key});

  @override
  State<AlarmBarengApp> createState() => _AlarmBarengAppState();
}

class _AlarmBarengAppState extends State<AlarmBarengApp> {
  StreamSubscription<AlarmSet>? _sub;
  int? _showingId;

  @override
  void initState() {
    super.initState();
    // Alarm.ringing adalah ValueStream: langsung kirim status terakhir saat
    // di-listen, jadi alarm yang membangunkan app (cold start lewat
    // full-screen intent) tetap terdeteksi.
    _sub = Alarm.ringing.listen(_onRing);
  }

  void _onRing(AlarmSet set) {
    if (set.alarms.isEmpty) {
      // alarm dimatikan dari luar (mis. tombol di notifikasi)
      if (_showingId != null) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
      return;
    }

    final alarm = set.alarms.first;
    if (_showingId == alarm.id) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      // navigator belum terpasang (cold start) -> coba lagi setelah frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRing(set));
      return;
    }

    _showingId = alarm.id;
    nav
        .push<Duration>(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RingScreen(alarm: alarm),
        ))
        .then((delta) {
      _showingId = null;
      if (delta != null) {
        final sec = (delta.inMilliseconds / 1000).toStringAsFixed(1);
        messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('Check-in $sec detik setelah alarm bunyi')));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Bareng',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const RoomListScreen(),
    );
  }
}
import 'package:flutter/material.dart';

import './services/alarmService.dart';
import './datamodels/data.dart';
import './UI/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  alarmService = AlarmService(await SqliteAlarmRepository.open());
  await alarmService.init();
  runApp(const AlarmBarengApp());
}

class AlarmBarengApp extends StatelessWidget {
  const AlarmBarengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm Bareng',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const RoomListScreen(),
    );
  }
}
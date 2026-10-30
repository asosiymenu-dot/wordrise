import 'package:flutter/material.dart';

import 'app/wordrise_app.dart';
import 'services/push_notification_service.dart';

import 'services/audio_haptic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.bootstrap();
  await AudioHapticService.instance.init();
  runApp(const WordRiseApp());
}

// 📦 Package imports:

import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

@singleton
class PushNotificationService {
  late AndroidNotificationChannel channel;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _isFlutterLocalNotificationsInitialized = false;

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }
    tz.initializeTimeZones();
    channel = const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    DarwinInitializationSettings darwinInitializationSettings =
        const DarwinInitializationSettings();

    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: darwinInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isFlutterLocalNotificationsInitialized = true;
  }

  void scheduleNotificationforTheDay({
    required String title,
    required String message,
    required DateTime date,
  }) {
    flutterLocalNotificationsPlugin.zonedSchedule(
      Random().nextInt(100),
      title,
      message,
      tz.TZDateTime.from(date, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleRepeatingTask({
    required DateTime startDate,
    required Duration interval,
  }) async {
    const iOSBackgroundAppRefresh =
        "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh";

    Workmanager().registerPeriodicTask(
      iOSBackgroundAppRefresh,
      "id",
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: startDate.difference(DateTime.now()),
      frequency: interval,
    );
  }
}

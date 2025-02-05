import 'dart:developer';

import 'package:aut_all_research/di/di.dart';
import 'package:aut_all_research/schedule_notification.dart';
import 'package:aut_all_research/utils/notification_service.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      log("FROM BACKGROUND");

      final pushNotificationService = PushNotificationService();

      await pushNotificationService.setupFlutterNotifications();

      // Check for notifications on this day then based on start date and the interval set in the notification, calculate and run the scheduleNotificationForTheDay.
      const title = "This will come from local db";
      const message = "This will come from local db";

      pushNotificationService.scheduleNotificationforTheDay(
          title: title,
          message: message,
          date: DateTime.now().add(
            const Duration(
              minutes: 1,
            ),
          ));
    } catch (e) {
      log(e.toString());
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PathService.initPath();
  await configureDependencies();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  runApp(const AppLauncher());
}

class AppLauncher extends StatelessWidget {
  const AppLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ScheduleNotification(),
      themeMode: ThemeMode.dark,
    );
  }
}

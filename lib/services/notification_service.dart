import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/detail_screen.dart';
import 'database_helper.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
  final payload = notificationResponse.payload;
  if (payload == null) return;
  final parts = payload.split('|');
  if (parts.isEmpty) return;

  final id = int.tryParse(parts[0]);
  if (id == null) return;

  // Cancel/Clear the notification
  await FlutterLocalNotificationsPlugin().cancel(id);

  if (notificationResponse.actionId == 'baca_link' ||
      notificationResponse.actionId == null) {
    // Action 'Buka Link' or tap on the main body
    final link = await DatabaseHelper.instance.readLink(id);
    if (link != null) {
      link.hasUpdate = false;
      await DatabaseHelper.instance.update(link);

      // Open screen using app's main navigator Key
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => DetailScreen(link: link)),
        );
      } else {
        NotificationService.pendingRouteLinkId = id;
      }
    }
  } else if (notificationResponse.actionId == 'baca') {
    // Action 'Tandai Dibaca'
    final link = await DatabaseHelper.instance.readLink(id);
    if (link != null) {
      link.hasUpdate = false;
      await DatabaseHelper.instance.update(link);
    }
  }
}

class NotificationService {
  static int? pendingRouteLinkId;

  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await localNotifier.setup(
        appName: 'NotifyMe',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: notificationTapBackground,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      if (Platform.isAndroid) {
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    }
  }

  Future<void> showUpdateNotification(
      int id, String title, String body, String url) async {
    // Windows Notification
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      LocalNotification notification = LocalNotification(
        identifier: id.toString(),
        title: title,
        body: body,
        actions: [
          LocalNotificationAction(text: 'Buka'),
          LocalNotificationAction(text: 'Tandai Dibaca'),
        ],
      );

      notification.onShow = () {};
      notification.onClick = () async {
        // Handle click action (Default Open Link)
        final link = await DatabaseHelper.instance.readLink(id);
        if (link != null) {
          link.hasUpdate = false;
          await DatabaseHelper.instance.update(link);

          if (navigatorKey.currentState != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => DetailScreen(link: link)),
            );
          } else {
            NotificationService.pendingRouteLinkId = id;
          }
        }
      };
      notification.onClickAction = (actionIndex) async {
        if (actionIndex == 0) {
          // Open url
          final link = await DatabaseHelper.instance.readLink(id);
          if (link != null) {
            link.hasUpdate = false;
            await DatabaseHelper.instance.update(link);

            if (navigatorKey.currentState != null) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => DetailScreen(link: link)),
              );
            } else {
              NotificationService.pendingRouteLinkId = id;
            }
          }
        } else if (actionIndex == 1) {
          // Mark as read
          final link = await DatabaseHelper.instance.readLink(id);
          if (link != null) {
            link.hasUpdate = false;
            await DatabaseHelper.instance.update(link);
          }
        }
      };

      await notification.show();
    } else {
      // Mobile Notification
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails('notifyme_updates', 'Pembaruan Website',
              channelDescription:
                  'Notifikasi jika ada pembaruan pada website yang dipantau',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
              styleInformation: BigTextStyleInformation(
                body,
                contentTitle: title,
                summaryText: url,
              ),
              actions: [
            const AndroidNotificationAction('baca_link', 'Buka Link',
                showsUserInterface: true, cancelNotification: true),
            const AndroidNotificationAction('baca', 'Tandai Dibaca',
                showsUserInterface: false, cancelNotification: true),
          ]);

      NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: '$id|$url',
      );
    }
  }
}

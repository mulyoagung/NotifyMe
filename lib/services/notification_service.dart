import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
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
  
  final url = parts.length > 1 ? parts.sublist(1).join('|') : '';

  // Cancel/Clear the notification
  await FlutterLocalNotificationsPlugin().cancel(id);

  if (notificationResponse.actionId == 'baca' || notificationResponse.actionId == null) {
    // Action 'Baca' or tap on the main body
    final link = await DatabaseHelper.instance.readLink(id);
    if (link != null) {
      link.hasUpdate = false;
      await DatabaseHelper.instance.update(link);
    }
    // Launch the URL
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  } else if (notificationResponse.actionId == 'baca_nanti') {
    // Action 'Baca Nanti' (read later/snooze)
    final link = await DatabaseHelper.instance.readLink(id);
    if (link != null) {
      link.hasUpdate = true;
      await DatabaseHelper.instance.update(link);
    }
  }
}

class NotificationService {
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
      notification.onClick = () {
        // Handle click action
      };
      notification.onClickAction = (actionIndex) {
        if (actionIndex == 0) {
          // Open url
        } else if (actionIndex == 1) {
          // Mark as read
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
            const AndroidNotificationAction('baca', 'Baca',
                showsUserInterface: false),
            const AndroidNotificationAction('baca_nanti', 'Baca Nanti',
                showsUserInterface: false),
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

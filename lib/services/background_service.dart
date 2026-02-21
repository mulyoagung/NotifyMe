import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'scraper_service.dart';
import 'notification_service.dart';

const String backgroundTaskKey = "com.notifyme.backgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // In background isolates, make sure to initialize bindings
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.instance.init();

    if (!kIsWeb && Platform.isAndroid) {
      await _checkUpdates();
    }
    return Future.value(true);
  });
}

Future<void> _checkUpdates() async {
  final prefs = await SharedPreferences.getInstance();
  final bool pushEnabled = prefs.getBool('pushEnabled') ?? true;
  final int reminderMinutes = prefs.getInt('reminderMinutes') ?? 15;

  final links = await DatabaseHelper.instance.readAllLinks();
  for (var link in links) {
    if (!link.isActive) continue;

    final elapsedMinutes =
        DateTime.now().difference(link.lastCheckedAt).inMinutes;

    // ----- REMINDER LOGIC -----
    if (link.hasUpdate && elapsedMinutes >= reminderMinutes) {
      if (pushEnabled) {
        await NotificationService.instance.showUpdateNotification(
          link.id ?? 0,
          '🔔 Reminder: Update on ${link.name}',
          'This update is waiting for you to view. Tap to open or Mark as Read.',
          link.url,
        );
      }
      // Update the checked time to reset the reminder loop
      link.lastCheckedAt = DateTime.now();
      await DatabaseHelper.instance.update(link);
      continue;
    }

    // If there is an unseen update but reminder time hasn't passed, do nothing
    if (link.hasUpdate) continue;

    // ----- NORMAL FETCH LOGIC -----
    if (elapsedMinutes >= link.intervalMinutes) {
      final newContent = await ScraperService.fetchAndExtract(link);

      if (newContent != null) {
        if (link.lastSnapshot != newContent) {
          link.hasUpdate = true;
          if (pushEnabled) {
            await NotificationService.instance.showUpdateNotification(
              link.id ?? 0,
              'Pembaruan pada ${link.name}',
              '''Terdapat perubahan pada halaman yang dipantau. Buka notifikasi ini untuk detail lebih lanjut.\n\nSimpulan Konten:\n${newContent.length > 200 ? newContent.substring(0, 200) + '...' : newContent}''',
              link.url,
            );
          }
        }
        link.lastSnapshot = newContent;
      } else {
        // Fetch failed
        print('Fetch failed for ${link.name}');
      }

      link.lastCheckedAt = DateTime.now();
      await DatabaseHelper.instance.update(link);
    }
  }
}

class BackgroundService {
  static Timer? _desktopTimer;

  static Future<void> init() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      // WorkManager Initialization for DOZE mode minimum 15 minutes.
      await Workmanager().initialize(
        callbackDispatcher, // The top level function
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        "1",
        backgroundTaskKey,
        frequency: const Duration(minutes: 15),
      );

      // Foreground active loop for instant test/updates while app is open
      _desktopTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _checkUpdates();
      });
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Background timer for Desktop
      _desktopTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _checkUpdates();
      });
    }
  }

  static Future<void> stop() async {
    if (Platform.isAndroid) {
      await Workmanager().cancelAll();
    } else {
      _desktopTimer?.cancel();
    }
  }
}

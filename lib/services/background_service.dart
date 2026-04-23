import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    DartPluginRegistrant.ensureInitialized();
    await NotificationService.instance.init();

    if (!kIsWeb && Platform.isAndroid) {
      await _checkUpdates();
    }
    return Future.value(true);
  });
}

/// Build a human-readable notification body from HTML-fingerprint snapshots.
/// Shows the innerText of newly added children (up to 3 items).
String _formatSummary(String newRaw, String oldRaw) {
  try {
    final newItems = decodeSnapshots(newRaw);
    final oldItems = decodeSnapshots(oldRaw);
    final newOnes = diffSnapshots(oldItems, newItems);
    if (newOnes.isEmpty) {
      // Fallback: just show first item's key
      return newItems.isNotEmpty ? newItems.first.key : 'Konten berubah.';
    }
    return newOnes.take(3).map((e) => '\u2022 ${e.key}').join('\n');
  } catch (_) {
    return 'Konten berubah.';
  }
}

Future<void> _checkUpdates() async {
  // Always verify internet connection to prevent battery drain on retries
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('Device is offline. Skipping update checks.');
      return;
    }
  } catch (e) {
    print('Connectivity check failed: \$e');
  }

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
        // ── HTML-fingerprint Set diff ──────────────────────────────────────
        // Compare by unique text keys (position-independent), not raw strings.
        final oldItems = decodeSnapshots(link.lastSnapshot);
        final newItems = decodeSnapshots(newContent);
        final added   = diffSnapshots(oldItems, newItems);
        final removed = diffSnapshots(newItems, oldItems);
        final hasChange = added.isNotEmpty || removed.isNotEmpty;
        // ──────────────────────────────────────────────────────────────────

        if (hasChange) {
          link.hasUpdate = true;
          link.previousSnapshot = link.lastSnapshot; // save old for diff view
          if (pushEnabled) {
            await NotificationService.instance.showUpdateNotification(
              link.id ?? 0,
              'Pembaruan pada \${link.name}',
              _formatSummary(newContent, link.lastSnapshot),
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
        initialDelay: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected, // Only run checking when online
          requiresBatteryNotLow: true, // Auto-skip checking when on low battery
        ),
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

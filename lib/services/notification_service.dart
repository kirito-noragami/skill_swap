import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Local notification service for session reminders.
/// 
/// ⚠️ Add these to pubspec.yaml:
///   flutter_local_notifications: ^17.0.0
///   timezone: ^0.9.4
///
/// ⚠️ Android: add to AndroidManifest.xml inside <manifest>:
///   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
///   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
///
/// ⚠️ iOS: add to Info.plist:
///   <key>UIBackgroundModes</key><array><string>fetch</string></array>
///
/// NOTE: Local notifications work when app is background/foreground.
/// For killed-app notifications, wire up FCM later.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Schedules T-10 and T-5 notifications for a session.
  Future<void> scheduleSessionNotifications({
    required String sessionId,
    required String helperName,
    required String requestTitle,
    required DateTime sessionTime,
  }) async {
    await init();

    final tenMinBefore = sessionTime.subtract(const Duration(minutes: 10));
    final fiveMinBefore = sessionTime.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    // T-10 notification
    if (tenMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        sessionId.hashCode,
        '⏰ جلستك تبدأ قريباً!',
        'جلستك مع $helperName في "$requestTitle" تبدأ خلال 10 دقائق. استعد!',
        tz.TZDateTime.from(tenMinBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'session_reminders', 'Session Reminders',
            importance: Importance.high, priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // T-5 notification (chat unlocks)
    if (fiveMinBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        sessionId.hashCode + 1,
        '🔓 الغرفة مفتوحة الآن!',
        'يمكنك الدخول للمحادثة مع $helperName في "$requestTitle" الآن.',
        tz.TZDateTime.from(fiveMinBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'session_reminders', 'Session Reminders',
            importance: Importance.max, priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelSessionNotifications(String sessionId) async {
    await _plugin.cancel(sessionId.hashCode);
    await _plugin.cancel(sessionId.hashCode + 1);
  }
}
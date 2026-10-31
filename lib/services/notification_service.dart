import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/case_model.dart';
import '../models/schedule_model.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails('casecraft_reminders', 'CaseCraft Reminders', channelDescription: 'Hearing, update and schedule reminders', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

  Future<void> rescheduleAll(List<LegalCase> cases, List<ScheduleItem> schedules, {required bool enabled}) async {
    await init();
    await plugin.cancelAll();
    if (!enabled) return;
    for (final c in cases) {
      await scheduleCase(c);
    }
    for (final s in schedules) {
      await scheduleSchedule(s);
    }
  }

  Future<void> scheduleCase(LegalCase item) async {
    await init();
    if (item.nextHearing == null || item.status == CaseStatus.disposed) return;
    final hearing = item.nextHearing!;
    final dayBeforeDate = hearing.subtract(const Duration(days: 1));
    final dayBefore = tz.TZDateTime(tz.local, dayBeforeDate.year, dayBeforeDate.month, dayBeforeDate.day, 9);
    final updateAt = tz.TZDateTime(tz.local, hearing.year, hearing.month, hearing.day, 18, 30);
    if (dayBefore.isAfter(tz.TZDateTime.now(tz.local))) {
      await _schedule(_id(item.id, 1), dayBefore, 'Tomorrow: ${displayCase(item)}', '${item.court.isEmpty ? 'Hearing' : item.court} • ${item.hearingPurpose.isEmpty ? 'Case hearing' : item.hearingPurpose}');
    }
    if (updateAt.isAfter(tz.TZDateTime.now(tz.local))) {
      await _schedule(_id(item.id, 2), updateAt, 'Update case: ${displayCase(item)}', 'Record today\'s outcome and set the next date.');
    }
  }

  Future<void> scheduleSchedule(ScheduleItem item) async {
    await init();
    if (!item.reminderEnabled || item.weekdays.isEmpty) return;
    final now = tz.TZDateTime.now(tz.local);
    for (final weekday in item.weekdays) {
      var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, item.startMinutes ~/ 60, item.startMinutes % 60);
      var diff = weekday - candidate.weekday;
      if (diff < 0 || (diff == 0 && !candidate.isAfter(now))) diff += 7;
      candidate = candidate.add(Duration(days: diff));
      final reminder = candidate.subtract(const Duration(minutes: 30));
      if (reminder.isAfter(now)) {
        await plugin.zonedSchedule(
          id: _id(item.id, 20 + weekday),
          scheduledDate: reminder,
          title: 'Upcoming: ${item.title}',
          body: '${formatMinutes(item.startMinutes)} • ${item.category}',
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'casecraft',
        );
      }
    }
  }

  Future<void> _schedule(int id, tz.TZDateTime when, String title, String body) async {
    await plugin.zonedSchedule(id: id, scheduledDate: when, title: title, body: body, notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: 'casecraft');
  }

  int _id(String value, int salt) {
    final raw = '$value:$salt'.codeUnits.fold<int>(17, (p, e) => (p * 31 + e) & 0x7fffffff);
    return raw == 0 ? salt : raw;
  }

  String displayCase(LegalCase c) => c.caseNumber.trim().isEmpty ? c.caseTitle : c.caseNumber;
}

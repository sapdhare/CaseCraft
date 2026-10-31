import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/case_model.dart';
import '../models/schedule_model.dart';

/// On-device reminders. Scheduled with the OS alarm system, so they fire with no network
/// and survive reboots (see the boot receiver in AndroidManifest.xml).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();

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

  /// Rebuilds every reminder. Calls run one at a time and never throw: a reminder problem
  /// must not stop a case from saving.
  Future<void> rescheduleAll(List<LegalCase> cases, List<ScheduleItem> schedules, {required bool enabled}) {
    final snapshotCases = List.of(cases), snapshotSchedules = List.of(schedules);
    return _queue = _queue.then((_) => _rescheduleAll(snapshotCases, snapshotSchedules, enabled)).catchError((Object e) {
      debugPrint('CaseCraft reminders not rebuilt: $e');
    });
  }

  Future<void> _rescheduleAll(List<LegalCase> cases, List<ScheduleItem> schedules, bool enabled) async {
    await init();
    await plugin.cancelAll();
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    final pending = <_Reminder>[for (final c in cases) ..._caseReminders(c), for (final s in schedules) ..._scheduleReminders(s, now)]
        .where((r) => r.when.isAfter(now))
        .toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    // iOS keeps only 64 pending notifications; keep the soonest.
    final limit = Platform.isIOS ? 60 : 400;
    for (final r in pending.take(limit)) {
      await plugin.zonedSchedule(
        id: r.id,
        scheduledDate: r.when,
        title: r.title,
        body: r.body,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: r.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
        payload: 'casecraft',
      );
    }
  }

  List<_Reminder> _caseReminders(LegalCase item) {
    final hearing = item.nextHearing;
    if (hearing == null || item.status == CaseStatus.disposed) return const [];
    final name = displayCase(item);
    final where = item.court.isEmpty ? 'Hearing' : item.court;
    final purpose = item.hearingPurpose.isEmpty ? 'Case hearing' : item.hearingPurpose;
    final dayBefore = hearing.subtract(const Duration(days: 1));
    return [
      _Reminder(_id(item.id, 1), tz.TZDateTime(tz.local, dayBefore.year, dayBefore.month, dayBefore.day, 9), 'Tomorrow: $name', '$where • $purpose'),
      _Reminder(_id(item.id, 3), tz.TZDateTime(tz.local, hearing.year, hearing.month, hearing.day, 8), 'Today: $name', '$where • $purpose'),
      _Reminder(_id(item.id, 2), tz.TZDateTime(tz.local, hearing.year, hearing.month, hearing.day, 18, 30), 'Update case: $name', 'Record today\'s outcome, fees received and the next date.'),
    ];
  }

  List<_Reminder> _scheduleReminders(ScheduleItem item, tz.TZDateTime now) {
    if (!item.reminderEnabled) return const [];
    return [
      for (final weekday in item.weekdays)
        _Reminder(
          _id(item.id, 20 + weekday),
          _nextWeekday(now, weekday, item.startMinutes).subtract(const Duration(minutes: 30)),
          'Upcoming: ${item.title}',
          '${formatMinutes(item.startMinutes)} • ${item.category}',
          weekly: true,
        ),
    ];
  }

  /// Next occurrence of [weekday] at [minutes] whose 30-minute-early reminder is still ahead.
  tz.TZDateTime _nextWeekday(tz.TZDateTime now, int weekday, int minutes) {
    var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    final diff = (weekday - candidate.weekday) % 7;
    candidate = candidate.add(Duration(days: diff));
    if (!candidate.subtract(const Duration(minutes: 30)).isAfter(now)) candidate = candidate.add(const Duration(days: 7));
    return candidate;
  }

  int _id(String value, int salt) {
    final raw = '$value:$salt'.codeUnits.fold<int>(17, (p, e) => (p * 31 + e) & 0x7fffffff);
    return raw == 0 ? salt : raw;
  }

  String displayCase(LegalCase c) => c.caseNumber.trim().isEmpty ? c.caseTitle : c.caseNumber;
}

class _Reminder {
  final int id;
  final tz.TZDateTime when;
  final String title;
  final String body;
  final bool weekly;
  const _Reminder(this.id, this.when, this.title, this.body, {this.weekly = false});
}

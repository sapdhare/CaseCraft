import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/case_model.dart';
import '../models/schedule_model.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  AppState(this.storage, this.notifications);
  final StorageService storage;
  final NotificationService notifications;
  final _uuid = const Uuid();

  List<LegalCase> cases = [];
  List<ScheduleItem> schedule = [];
  bool ready = false;
  String search = '';
  CaseStatusFilter filter = CaseStatusFilter.active;
  String practitionerName = 'Advocate';
  String firmName = 'CaseCraft Legal';
  bool notificationsEnabled = true;

  Future<void> load() async {
    cases = storage.getCases();
    schedule = storage.getSchedule();
    practitionerName = storage.practitionerName;
    firmName = storage.firmName;
    notificationsEnabled = storage.notificationsEnabled;
    _sort();
    ready = true;
    notifyListeners();
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
  }

  void _sort() {
    cases.sort((a, b) => (a.nextHearing ?? DateTime(2999)).compareTo(b.nextHearing ?? DateTime(2999)));
    schedule.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  String newId() => _uuid.v4();
  void setSearch(String value) { search = value; notifyListeners(); }
  void setFilter(CaseStatusFilter value) { filter = value; notifyListeners(); }

  List<LegalCase> get visibleCases {
    final q = search.trim().toLowerCase();
    return cases.where((c) {
      final statusOk = switch (filter) { CaseStatusFilter.active => c.status != CaseStatus.disposed, CaseStatusFilter.disposed => c.status == CaseStatus.disposed, CaseStatusFilter.all => true };
      final hay = [c.caseNumber, c.caseTitle, c.clientName, c.opponentName, c.court, c.judge, c.sections, c.caseNature].join(' ').toLowerCase();
      return statusOk && (q.isEmpty || hay.contains(q));
    }).toList();
  }

  List<ScheduleItem> get todaySchedule {
    final day = DateTime.now().weekday;
    return schedule.where((s) => s.weekdays.contains(day)).toList();
  }

  List<LegalCase> get hearingsToday => cases.where((c) => c.status != CaseStatus.disposed && c.nextHearing != null && _sameDay(c.nextHearing!, DateTime.now())).toList();
  List<LegalCase> get needsUpdate => cases.where((c) => c.status != CaseStatus.disposed && c.nextHearing != null && _sameDay(c.nextHearing!, DateTime.now()) && !_updatedToday(c)).toList();
  int get activeCount => cases.where((c) => c.status != CaseStatus.disposed).length;
  int get disposedCount => cases.where((c) => c.status == CaseStatus.disposed).length;
  int get upcoming7 => cases.where((c) => c.status != CaseStatus.disposed && c.nextHearing != null && c.nextHearing!.isAfter(DateTime.now().subtract(const Duration(days: 1))) && c.nextHearing!.isBefore(DateTime.now().add(const Duration(days: 8)))).length;
  double get outstandingFees => cases.fold(0, (sum, c) => sum + c.outstanding);

  LegalCase? get nextHearing {
    final list = cases.where((c) => c.status != CaseStatus.disposed && c.nextHearing != null && c.nextHearing!.isAfter(DateTime.now().subtract(const Duration(hours: 1)))).toList();
    list.sort((a, b) => a.nextHearing!.compareTo(b.nextHearing!));
    return list.isEmpty ? null : list.first;
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _updatedToday(LegalCase c) => c.updates.any((u) => _sameDay(u.date, DateTime.now()));

  Future<void> upsertCase(LegalCase item) async {
    await storage.saveCase(item);
    cases.removeWhere((c) => c.id == item.id);
    cases.add(item);
    _sort();
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
    notifyListeners();
  }

  Future<void> deleteCase(LegalCase item) async {
    await storage.deleteCase(item.id);
    cases.removeWhere((c) => c.id == item.id);
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
    notifyListeners();
  }

  Future<void> addUpdate(LegalCase item, {required String outcome, required DateTime? nextDate, required String note}) async {
    final u = CaseUpdate(id: newId(), date: DateTime.now(), outcome: outcome, nextDate: nextDate, note: note);
    await upsertCase(item.copyWith(updates: [...item.updates, u], nextHearing: nextDate, clearNextHearing: nextDate == null));
  }

  Future<void> disposeCase(LegalCase item, DisposalResult result, {String note = ''}) async {
    final u = CaseUpdate(id: newId(), date: DateTime.now(), outcome: result == DisposalResult.allowed ? 'Case allowed' : 'Case rejected', note: note);
    await upsertCase(item.copyWith(status: CaseStatus.disposed, disposalResult: result, disposedOn: DateTime.now(), clearNextHearing: true, updates: [...item.updates, u]));
  }

  Future<void> upsertSchedule(ScheduleItem item) async {
    await storage.saveSchedule(item);
    schedule.removeWhere((s) => s.id == item.id);
    schedule.add(item);
    _sort();
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
    notifyListeners();
  }

  Future<void> deleteSchedule(ScheduleItem item) async {
    await storage.deleteSchedule(item.id);
    schedule.removeWhere((s) => s.id == item.id);
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
    notifyListeners();
  }

  List<ScheduleItem> conflictsFor(int start, int end, {required int weekday, String? ignoreId}) => schedule.where((s) => s.id != ignoreId && s.weekdays.contains(weekday) && start < s.endMinutes && end > s.startMinutes).toList();

  Future<void> saveProfile(String name, String firm) async {
    await storage.saveProfile(practitionerName: name, firmName: firm);
    practitionerName = storage.practitionerName;
    firmName = storage.firmName;
    notifyListeners();
  }

  Future<void> setNotifications(bool enabled) async {
    notificationsEnabled = enabled;
    await storage.setNotificationsEnabled(enabled);
    await notifications.rescheduleAll(cases, schedule, enabled: enabled);
    notifyListeners();
  }

  Future<int> restoreBackup(String path) async {
    final count = await storage.restoreFromJson(path);
    cases = storage.getCases();
    schedule = storage.getSchedule();
    practitionerName = storage.practitionerName;
    firmName = storage.firmName;
    notificationsEnabled = storage.notificationsEnabled;
    _sort();
    await notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);
    notifyListeners();
    return count;
  }
}

enum CaseStatusFilter { active, disposed, all }

import 'dart:async';
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
  CaseStatusFilter filter = CaseStatusFilter.active;
  String practitionerName = 'Advocate';
  String firmName = 'CaseCraft Legal';
  bool notificationsEnabled = true;
  bool appLockEnabled = false;

  Future<void> load() async {
    cases = storage.getCases();
    schedule = storage.getSchedule();
    practitionerName = storage.practitionerName;
    firmName = storage.firmName;
    notificationsEnabled = storage.notificationsEnabled;
    appLockEnabled = storage.appLockEnabled;
    _sort();
    ready = true;
    notifyListeners();
    // Not awaited: the first-run permission prompt must not hold the splash screen.
    unawaited(_reschedule());
  }

  void _sort() {
    cases.sort((a, b) => (a.nextHearing ?? DateTime(2999)).compareTo(b.nextHearing ?? DateTime(2999)));
    schedule.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  Future<void> _reschedule() => notifications.rescheduleAll(cases, schedule, enabled: notificationsEnabled);

  String newId() => _uuid.v4();
  void setFilter(CaseStatusFilter value) { filter = value; notifyListeners(); }

  List<LegalCase> get visibleCases => cases.where((c) => switch (filter) {
        CaseStatusFilter.active => c.status != CaseStatus.disposed,
        CaseStatusFilter.disposed => c.status == CaseStatus.disposed,
        CaseStatusFilter.all => true,
      }).toList();

  List<LegalCase> searchCases(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return cases.where((c) => [c.caseNumber, c.caseTitle, c.clientName, c.clientContact, c.panNumber, c.opponentName, c.court, c.judge, c.sections, c.caseNature, c.type].join(' ').toLowerCase().contains(q)).toList();
  }

  List<ScheduleItem> get todaySchedule {
    final day = DateTime.now().weekday;
    return schedule.where((s) => s.weekdays.contains(day)).toList();
  }

  List<LegalCase> get hearingsToday => cases.where((c) => c.status != CaseStatus.disposed && c.nextHearing != null && _sameDay(c.nextHearing!, DateTime.now())).toList();
  List<LegalCase> get needsUpdate => hearingsToday.where((c) => !_updatedToday(c)).toList();
  int get activeCount => cases.where((c) => c.status != CaseStatus.disposed).length;
  int get disposedCount => cases.where((c) => c.status == CaseStatus.disposed).length;
  // Hearing dates are stored as midnight, so compare against the start of today.
  DateTime get _today { final n = DateTime.now(); return DateTime(n.year, n.month, n.day); }
  bool _fromToday(LegalCase c) => c.status != CaseStatus.disposed && c.nextHearing != null && !c.nextHearing!.isBefore(_today);
  int get upcoming7 => cases.where((c) => _fromToday(c) && c.nextHearing!.isBefore(_today.add(const Duration(days: 8)))).length;
  double get outstandingFees => roundMoney(cases.fold<double>(0, (sum, c) => sum + c.outstanding));

  LegalCase? get nextHearing {
    final list = cases.where(_fromToday).toList();
    list.sort((a, b) => a.nextHearing!.compareTo(b.nextHearing!));
    return list.isEmpty ? null : list.first;
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _updatedToday(LegalCase c) => c.updates.any((u) => _sameDay(u.date, DateTime.now()));

  /// Saves to the encrypted local store first; memory and reminders follow only once that succeeded.
  /// Reminders rebuild in the background (queued, never throwing) so saving stays instant.
  Future<void> upsertCase(LegalCase item) async {
    final saved = item.copyWith(updatedAt: DateTime.now());
    await storage.saveCase(saved);
    cases.removeWhere((c) => c.id == saved.id);
    cases.add(saved);
    _sort();
    notifyListeners();
    unawaited(_reschedule());
  }

  Future<void> deleteCase(LegalCase item) async {
    await storage.deleteCase(item.id);
    cases.removeWhere((c) => c.id == item.id);
    notifyListeners();
    unawaited(_reschedule());
  }

  LegalCase _latest(LegalCase item) => cases.firstWhere((c) => c.id == item.id, orElse: () => item);

  Future<void> addUpdate(LegalCase item, {required String outcome, required DateTime? nextDate, required String note, double amountReceived = 0}) async {
    final c = _latest(item);
    final now = DateTime.now();
    final u = CaseUpdate(id: newId(), date: now, outcome: outcome, nextDate: nextDate, note: note);
    final payments = amountReceived > 0 ? [...c.payments, Payment(id: newId(), date: now, amount: roundMoney(amountReceived), note: 'Received at hearing')] : c.payments;
    await upsertCase(c.copyWith(updates: [...c.updates, u], payments: payments, nextHearing: nextDate, clearNextHearing: nextDate == null));
  }

  Future<void> addPayment(LegalCase item, {required double amount, required DateTime date, String note = ''}) async {
    final c = _latest(item);
    await upsertCase(c.copyWith(payments: [...c.payments, Payment(id: newId(), date: date, amount: roundMoney(amount), note: note)]));
  }

  Future<void> deletePayment(LegalCase item, String paymentId) async {
    final c = _latest(item);
    await upsertCase(c.copyWith(payments: c.payments.where((p) => p.id != paymentId).toList()));
  }

  Future<void> transferCase(LegalCase item, {required String toCourt, required String toJudge, required DateTime date, String reason = ''}) async {
    final c = _latest(item);
    final t = CourtTransfer(id: newId(), date: date, fromCourt: c.court, toCourt: toCourt, fromJudge: c.judge, toJudge: toJudge, reason: reason);
    final u = CaseUpdate(id: newId(), date: date, outcome: 'Transferred to $toCourt', note: [if (c.court.isNotEmpty) 'From ${c.court}', if (reason.isNotEmpty) reason].join(' • '));
    await upsertCase(c.copyWith(court: toCourt, judge: toJudge, transfers: [...c.transfers, t], updates: [...c.updates, u]));
  }

  Future<void> disposeCase(LegalCase item, DisposalResult result, {String note = ''}) async {
    final c = _latest(item);
    final u = CaseUpdate(id: newId(), date: DateTime.now(), outcome: result == DisposalResult.allowed ? 'Case allowed' : 'Case rejected', note: note);
    await upsertCase(c.copyWith(status: CaseStatus.disposed, disposalResult: result, disposedOn: DateTime.now(), clearNextHearing: true, updates: [...c.updates, u]));
  }

  Future<void> upsertSchedule(ScheduleItem item) async {
    await storage.saveSchedule(item);
    schedule.removeWhere((s) => s.id == item.id);
    schedule.add(item);
    _sort();
    notifyListeners();
    unawaited(_reschedule());
  }

  Future<void> deleteSchedule(ScheduleItem item) async {
    await storage.deleteSchedule(item.id);
    schedule.removeWhere((s) => s.id == item.id);
    notifyListeners();
    unawaited(_reschedule());
  }

  List<ScheduleItem> conflictsFor(int start, int end, {required int weekday, String? ignoreId}) => schedule.where((s) => s.id != ignoreId && s.weekdays.contains(weekday) && start < s.endMinutes && end > s.startMinutes).toList();

  Future<void> saveProfile(String name, String firm) async {
    await storage.saveProfile(practitionerName: name, firmName: firm);
    practitionerName = storage.practitionerName;
    firmName = storage.firmName;
    notifyListeners();
  }

  Future<void> setNotifications(bool enabled) async {
    await storage.setNotificationsEnabled(enabled);
    notificationsEnabled = enabled;
    notifyListeners();
    unawaited(_reschedule());
  }

  Future<void> setAppLock(bool enabled) async {
    await storage.setAppLockEnabled(enabled);
    appLockEnabled = enabled;
    notifyListeners();
  }

  Future<int> restoreBackup(String path) async {
    final count = await storage.restoreFromJson(path);
    await load();
    return count;
  }
}

enum CaseStatusFilter { active, disposed, all }

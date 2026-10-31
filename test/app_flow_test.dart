import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:casecraft/main.dart';
import 'package:casecraft/models/case_model.dart';
import 'package:casecraft/models/schedule_model.dart';
import 'package:casecraft/services/notification_service.dart';
import 'package:casecraft/services/storage_service.dart';
import 'package:casecraft/state/app_state.dart';

/// In-memory stand-in for the encrypted Hive store.
class _MemoryStorage implements StorageService {
  final cases = <String, Map<String, dynamic>>{};
  final schedule = <String, Map<String, dynamic>>{};
  @override
  List<LegalCase> getCases() => cases.values.map(LegalCase.fromMap).toList();
  @override
  List<ScheduleItem> getSchedule() => schedule.values.map(ScheduleItem.fromMap).toList();
  @override
  Future<void> saveCase(LegalCase item) async => cases[item.id] = item.toMap();
  @override
  Future<void> deleteCase(String id) async => cases.remove(id);
  @override
  Future<void> saveSchedule(ScheduleItem item) async => schedule[item.id] = item.toMap();
  @override
  Future<void> deleteSchedule(String id) async => schedule.remove(id);
  @override
  String get practitionerName => 'Adv. Test';
  @override
  String get firmName => 'Test Chambers';
  @override
  bool get notificationsEnabled => false;
  @override
  bool get appLockEnabled => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lists build lazily, so scroll the page (not a text field's own scroller) until [f] exists.
Future<void> _show(WidgetTester tester, Finder f) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  if (f.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(f, 200, scrollable: page);
    } on StateError {
      await tester.scrollUntilVisible(f, -200, scrollable: page);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _show(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  final f = find.widgetWithText(TextField, label);
  await _show(tester, f);
  await tester.enterText(f, text);
}

void main() {
  for (final textScale in [1.0, 1.3]) {
    testWidgets('income-tax client: add, pay, transfer, update — small phone, text x$textScale', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final storage = _MemoryStorage();
      final state = AppState(storage, NotificationService.instance);
      await state.load();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const CaseCraftApp()));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Cases'));
      await _tap(tester, find.text('Add case'));

      // Required fields are enforced.
      await _tap(tester, find.text('Save case'));
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
      expect(storage.cases, isEmpty);
      await tester.pump(const Duration(seconds: 5)); // let the snackbar go

      await _tap(tester, find.text('Income Tax'));
      await _type(tester, 'Client name *', 'Ramesh Patil');
      await _type(tester, 'Mobile number', '9876543210');
      await _type(tester, 'PAN number *', 'abcde1234f');
      await _type(tester, 'Income-tax portal password', 'Pass@123');
      await _type(tester, 'Matter title *', 'ITR AY 2025-26');
      await _type(tester, 'Fee quoted to client', '50000');
      await _type(tester, 'Received now (optional)', '10000');
      await _tap(tester, find.text('Save case'));

      final saved = state.cases.single;
      expect(saved.panNumber, 'ABCDE1234F');
      expect(saved.panPassword, 'Pass@123');
      expect(saved.outstanding, 40000);

      await _tap(tester, find.text('ITR AY 2025-26'));
      await _show(tester, find.text('₹40,000'));
      expect(find.text('₹40,000'), findsOneWidget);
      expect(find.text('Pass@123'), findsNothing, reason: 'password is masked');

      await _tap(tester, find.text('Add payment'));
      await _type(tester, 'Amount *', '5000');
      await _tap(tester, find.text('Save payment'));
      expect(state.cases.single.outstanding, 35000);
      await _show(tester, find.text('₹35,000'));
      expect(find.text('₹35,000'), findsOneWidget);

      await _tap(tester, find.text('Transfer'));
      await _type(tester, 'New court *', 'ITAT Mumbai');
      await _tap(tester, find.text('Save transfer'));
      expect(state.cases.single.court, 'ITAT Mumbai');
      await _show(tester, find.text('Court transfers'));
      expect(find.text('Court transfers'), findsOneWidget);

      await _tap(tester, find.text('Update case'));
      await _type(tester, 'What happened today *', 'Documents submitted');
      await _type(tester, 'Money received today (optional)', '2500.50');
      await _tap(tester, find.text('Save update'));
      expect(state.cases.single.outstanding, 32499.5);
      await _show(tester, find.text('Documents submitted'));
      expect(find.text('Documents submitted'), findsOneWidget);

      // Persisted, not just in memory.
      expect(LegalCase.fromMap(storage.cases.values.single).payments.length, 3);
      expect(tester.takeException(), isNull);
    });
  }

  for (final textScale in [1.0, 1.3]) {
    testWidgets('every tab and dialog renders with data — small phone, text x$textScale', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final storage = _MemoryStorage();
      final now = DateTime.now();
      await storage.saveCase(
        LegalCase(
          id: 'c1',
          type: courtCase,
          caseNumber: 'RCS 1234/2026',
          caseTitle: 'Deshmukh v. Municipal Corporation of Greater Mumbai',
          clientName: 'Suresh Deshmukh',
          clientContact: '9876543210',
          opponentName: 'MCGM',
          opponentAdvocate: 'Adv. Rao',
          court: 'Bombay City Civil Court, Court Room 14',
          judge: 'H.H. Judge Kulkarni',
          caseNature: 'Civil suit',
          sections: 'Order 39 Rules 1 & 2 CPC',
          nextHearing: DateTime(now.year, now.month, now.day),
          hearingPurpose: 'Arguments on interim application',
          notes: '',
          totalFee: 1500000,
          payments: [Payment(id: 'p', date: now, amount: 250000.75)],
        ),
      );
      await storage.saveSchedule(
        const ScheduleItem(
          id: 's1',
          title: 'Chambers — client meetings and drafting',
          category: 'Work',
          startMinutes: 0,
          endMinutes: 23 * 60 + 59,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          location: 'Fort office',
          notes: '',
        ),
      );
      final state = AppState(storage, NotificationService.instance);
      await state.load();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const CaseCraftApp()));
      await tester.pumpAndSettle();
      expect(find.text('Need update'), findsOneWidget);

      await _tap(tester, find.text('Deshmukh v. Municipal Corporation of Greater Mumbai'));
      await _show(tester, find.text('Fees'));
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Cases'));
      await _tap(tester, find.text('All'));
      await _tap(tester, find.byIcon(Icons.search_rounded));
      await tester.enterText(find.byType(TextField).last, 'mcgm');
      await tester.pumpAndSettle();
      expect(find.text('Deshmukh v. Municipal Corporation of Greater Mumbai'), findsOneWidget);
      await _tap(tester, find.byIcon(Icons.arrow_back));

      await _tap(tester, find.text('Schedule'));
      await _tap(tester, find.byIcon(Icons.bolt_rounded));
      await _tap(tester, find.text('Close'));

      await _tap(tester, find.text('More'));
      await _tap(tester, find.text('Security & privacy'));
      await _tap(tester, find.text('OK'));
      await _tap(tester, find.text('Backup data'));
      await _tap(tester, find.text('Cancel'));
      await _tap(tester, find.byIcon(Icons.edit_rounded));
      await _tap(tester, find.text('Cancel'));
      expect(tester.takeException(), isNull);
    });
  }
}

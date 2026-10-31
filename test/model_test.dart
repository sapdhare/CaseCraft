import 'package:flutter_test/flutter_test.dart';
import 'package:casecraft/models/case_model.dart';
import 'package:casecraft/models/schedule_model.dart';

LegalCase _case({double fee = 10000, List<Payment> payments = const []}) => LegalCase(
      id: '1', type: incomeTaxCase, caseNumber: 'WP 1/2026', caseTitle: 'Test v State',
      clientName: 'Test Client', clientContact: '9999999999', panNumber: 'ABCDE1234F', panPassword: 's3cret!',
      opponentName: 'State', opponentAdvocate: 'A', court: 'High Court', judge: 'J', caseNature: 'Writ',
      sections: 'Art. 226', filingDate: DateTime(2026, 1, 1), nextHearing: DateTime(2026, 2, 1),
      hearingPurpose: 'Arguments', notes: 'Note', totalFee: fee, payments: payments,
      updates: [CaseUpdate(id: 'u', date: DateTime(2026, 1, 2), outcome: 'Adjourned')],
      transfers: [CourtTransfer(id: 't', date: DateTime(2026, 1, 3), fromCourt: 'District Court', toCourt: 'High Court', reason: 'Order')],
    );

void main() {
  test('legal case survives map round trip', () {
    final source = _case(payments: [Payment(id: 'p1', date: DateTime(2026, 1, 1), amount: 2500), Payment(id: 'p2', date: DateTime(2026, 1, 5), amount: 0.1)]);
    final copy = LegalCase.fromMap(source.toMap());
    expect(copy.caseNumber, source.caseNumber);
    expect(copy.panNumber, 'ABCDE1234F');
    expect(copy.panPassword, 's3cret!');
    expect(copy.feeReceived, 2500.1);
    expect(copy.outstanding, 7499.9);
    expect(copy.updates.single.outcome, 'Adjourned');
    expect(copy.transfers.single.toCourt, 'High Court');
  });

  test('exported map never contains the PAN password', () {
    final exported = _case().toMap(includeSecrets: false);
    expect(exported.containsKey('panPassword'), isFalse);
    expect(LegalCase.fromMap(exported).panPassword, '');
  });

  test('old records with only feeReceived become one payment', () {
    final legacy = _case().toMap()..remove('payments')..['feeReceived'] = 4000;
    final c = LegalCase.fromMap(legacy);
    expect(c.payments.single.amount, 4000);
    expect(c.outstanding, 6000);
  });

  test('overpayment shows as extra, not negative remaining', () {
    final c = _case(fee: 1000, payments: [Payment(id: 'p', date: DateTime(2026), amount: 1500)]);
    expect(c.outstanding, 0);
    expect(c.excessReceived, 500);
  });

  test('corrupt or hostile data does not crash parsing', () {
    final c = LegalCase.fromMap({'id': 5, 'totalFee': 'lots', 'nextHearing': 'tomorrow', 'payments': [null, 'x', {'amount': -50}], 'status': 'weird'});
    expect(c.id, '5');
    expect(c.totalFee, 0);
    expect(c.nextHearing, isNull);
    expect(c.payments.single.amount, 0);
    expect(c.status, CaseStatus.active);
    expect(c.type, courtCase);
    final s = ScheduleItem.fromMap({'id': 'a', 'startMinutes': 99999, 'weekdays': [0, 3, 'x', 9.0]});
    expect(s.startMinutes, 600);
    expect(s.weekdays, {3});
  });

  test('input validation', () {
    expect(isValidPan('abcde1234f'), isTrue);
    expect(isValidPan('ABCD1234F'), isFalse);
    expect(isValidPhone('+91 98765-43210'), isTrue);
    expect(isValidPhone('12ab'), isFalse);
    expect(parseAmount('1,50,000'), 150000);
    expect(parseAmount('-5'), isNull);
    expect(parseAmount('NaN'), isNull);
    expect(parseAmount('abc'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:casecraft/models/case_model.dart';

void main() {
  test('legal case survives map round trip', () {
    final source = LegalCase(
      id: '1', type: 'Court Case', caseNumber: 'WP 1/2026', caseTitle: 'Test v State',
      clientName: 'Test Client', clientContact: '9999999999', opponentName: 'State',
      opponentAdvocate: 'A', court: 'High Court', judge: 'J', caseNature: 'Writ',
      sections: 'Art. 226', filingDate: DateTime(2026, 1, 1), nextHearing: DateTime(2026, 2, 1),
      hearingPurpose: 'Arguments', notes: 'Note', totalFee: 10000, feeReceived: 2500,
      updates: [CaseUpdate(id: 'u', date: DateTime(2026,1,2), outcome: 'Adjourned')],
    );
    final copy = LegalCase.fromMap(source.toMap());
    expect(copy.caseNumber, source.caseNumber);
    expect(copy.outstanding, 7500);
    expect(copy.updates.single.outcome, 'Adjourned');
  });
}

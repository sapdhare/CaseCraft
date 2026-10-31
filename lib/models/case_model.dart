enum CaseStatus { active, stayed, disposed }
enum DisposalResult { allowed, rejected }

/// Stored values of [LegalCase.type].
const courtCase = 'Court Case';
const incomeTaxCase = 'Income Tax';
const otherMatter = 'Matter';

final _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
bool isValidPan(String value) => _panPattern.hasMatch(value.trim().toUpperCase());
bool isValidPhone(String value) => RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value.replaceAll(RegExp(r'[\s\-()]'), ''));

/// Parses a user-typed amount. Null for blank, negative, non-numeric or absurd values.
double? parseAmount(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', ''));
  if (v == null || !v.isFinite || v < 0 || v > 1e12) return null;
  return roundMoney(v);
}

double roundMoney(num v) => (v * 100).round() / 100;

DateTime? _date(dynamic v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
double _money(dynamic v) => v is num && v.isFinite && v >= 0 ? roundMoney(v) : 0;
String _str(dynamic v) => v == null ? '' : '$v';
List<T> _list<T>(dynamic v, T Function(Map) parse) =>
    v is List ? v.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList() : <T>[];

class CaseUpdate {
  final String id;
  final DateTime date;
  final String outcome;
  final DateTime? nextDate;
  final String note;

  const CaseUpdate({required this.id, required this.date, required this.outcome, this.nextDate, this.note = ''});

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'outcome': outcome,
        'nextDate': nextDate?.millisecondsSinceEpoch,
        'note': note,
      };

  factory CaseUpdate.fromMap(Map map) => CaseUpdate(
        id: _str(map['id']),
        date: _date(map['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        outcome: _str(map['outcome']),
        nextDate: _date(map['nextDate']),
        note: _str(map['note']),
      );
}

/// Money received from the client on a given date.
class Payment {
  final String id;
  final DateTime date;
  final double amount;
  final String note;

  const Payment({required this.id, required this.date, required this.amount, this.note = ''});

  Map<String, dynamic> toMap() => {'id': id, 'date': date.millisecondsSinceEpoch, 'amount': amount, 'note': note};

  factory Payment.fromMap(Map map) => Payment(
        id: _str(map['id']),
        date: _date(map['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        amount: _money(map['amount']),
        note: _str(map['note']),
      );
}

/// A move of the case from one court / judge to another.
class CourtTransfer {
  final String id;
  final DateTime date;
  final String fromCourt;
  final String toCourt;
  final String fromJudge;
  final String toJudge;
  final String reason;

  const CourtTransfer({
    required this.id,
    required this.date,
    required this.fromCourt,
    required this.toCourt,
    this.fromJudge = '',
    this.toJudge = '',
    this.reason = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'fromCourt': fromCourt,
        'toCourt': toCourt,
        'fromJudge': fromJudge,
        'toJudge': toJudge,
        'reason': reason,
      };

  factory CourtTransfer.fromMap(Map map) => CourtTransfer(
        id: _str(map['id']),
        date: _date(map['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        fromCourt: _str(map['fromCourt']),
        toCourt: _str(map['toCourt']),
        fromJudge: _str(map['fromJudge']),
        toJudge: _str(map['toJudge']),
        reason: _str(map['reason']),
      );
}

class CaseDocument {
  final String id;
  final String name;
  final String path;
  final DateTime addedOn;

  const CaseDocument({required this.id, required this.name, required this.path, required this.addedOn});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'path': path, 'addedOn': addedOn.millisecondsSinceEpoch};

  factory CaseDocument.fromMap(Map map) => CaseDocument(
        id: _str(map['id']),
        name: _str(map['name']),
        path: _str(map['path']),
        addedOn: _date(map['addedOn']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class LegalCase {
  final String id;
  final String type;
  final String caseNumber;
  final String caseTitle;
  final String clientName;
  final String clientContact;
  final String panNumber;
  /// Client's income-tax portal password. Kept only in the encrypted on-device store, never exported.
  final String panPassword;
  final String opponentName;
  final String opponentAdvocate;
  final String court;
  final String judge;
  /// Shown as "Case type" (civil suit, bail, writ…).
  final String caseNature;
  final String sections;
  final DateTime? filingDate;
  final DateTime? nextHearing;
  final String hearingPurpose;
  final String notes;
  final CaseStatus status;
  final DisposalResult? disposalResult;
  final DateTime? disposedOn;
  /// Fee quoted to the client.
  final double totalFee;
  final List<Payment> payments;
  final List<CaseUpdate> updates;
  final List<CourtTransfer> transfers;
  final List<CaseDocument> documents;
  /// Last local change; a cloud sync uses it to pick the newer copy.
  final DateTime? updatedAt;

  const LegalCase({
    required this.id,
    required this.type,
    required this.caseNumber,
    required this.caseTitle,
    required this.clientName,
    required this.clientContact,
    this.panNumber = '',
    this.panPassword = '',
    required this.opponentName,
    required this.opponentAdvocate,
    required this.court,
    required this.judge,
    required this.caseNature,
    required this.sections,
    this.filingDate,
    this.nextHearing,
    required this.hearingPurpose,
    required this.notes,
    this.status = CaseStatus.active,
    this.disposalResult,
    this.disposedOn,
    this.totalFee = 0,
    this.payments = const [],
    this.updates = const [],
    this.transfers = const [],
    this.documents = const [],
    this.updatedAt,
  });

  bool get isIncomeTax => type == incomeTaxCase;
  bool get isCourtCase => type == courtCase;
  double get feeReceived => roundMoney(payments.fold<double>(0, (s, p) => s + p.amount));
  double get outstanding => roundMoney((totalFee - feeReceived).clamp(0, double.infinity));
  double get excessReceived => roundMoney((feeReceived - totalFee).clamp(0, double.infinity));

  LegalCase copyWith({
    String? type,
    String? caseNumber,
    String? caseTitle,
    String? clientName,
    String? clientContact,
    String? panNumber,
    String? panPassword,
    String? opponentName,
    String? opponentAdvocate,
    String? court,
    String? judge,
    String? caseNature,
    String? sections,
    DateTime? filingDate,
    DateTime? nextHearing,
    bool clearNextHearing = false,
    String? hearingPurpose,
    String? notes,
    CaseStatus? status,
    DisposalResult? disposalResult,
    bool clearDisposalResult = false,
    DateTime? disposedOn,
    double? totalFee,
    List<Payment>? payments,
    List<CaseUpdate>? updates,
    List<CourtTransfer>? transfers,
    List<CaseDocument>? documents,
    DateTime? updatedAt,
  }) {
    return LegalCase(
      id: id,
      type: type ?? this.type,
      caseNumber: caseNumber ?? this.caseNumber,
      caseTitle: caseTitle ?? this.caseTitle,
      clientName: clientName ?? this.clientName,
      clientContact: clientContact ?? this.clientContact,
      panNumber: panNumber ?? this.panNumber,
      panPassword: panPassword ?? this.panPassword,
      opponentName: opponentName ?? this.opponentName,
      opponentAdvocate: opponentAdvocate ?? this.opponentAdvocate,
      court: court ?? this.court,
      judge: judge ?? this.judge,
      caseNature: caseNature ?? this.caseNature,
      sections: sections ?? this.sections,
      filingDate: filingDate ?? this.filingDate,
      nextHearing: clearNextHearing ? null : (nextHearing ?? this.nextHearing),
      hearingPurpose: hearingPurpose ?? this.hearingPurpose,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      disposalResult: clearDisposalResult ? null : (disposalResult ?? this.disposalResult),
      disposedOn: disposedOn ?? this.disposedOn,
      totalFee: totalFee ?? this.totalFee,
      payments: payments ?? this.payments,
      updates: updates ?? this.updates,
      transfers: transfers ?? this.transfers,
      documents: documents ?? this.documents,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// [includeSecrets] is false for anything that leaves the device (backups, cloud sync).
  Map<String, dynamic> toMap({bool includeSecrets = true}) => {
        'id': id,
        'type': type,
        'caseNumber': caseNumber,
        'caseTitle': caseTitle,
        'clientName': clientName,
        'clientContact': clientContact,
        'panNumber': panNumber,
        if (includeSecrets) 'panPassword': panPassword,
        'opponentName': opponentName,
        'opponentAdvocate': opponentAdvocate,
        'court': court,
        'judge': judge,
        'caseNature': caseNature,
        'sections': sections,
        'filingDate': filingDate?.millisecondsSinceEpoch,
        'nextHearing': nextHearing?.millisecondsSinceEpoch,
        'hearingPurpose': hearingPurpose,
        'notes': notes,
        'status': status.name,
        'disposalResult': disposalResult?.name,
        'disposedOn': disposedOn?.millisecondsSinceEpoch,
        'totalFee': totalFee,
        'payments': payments.map((e) => e.toMap()).toList(),
        'updates': updates.map((e) => e.toMap()).toList(),
        'transfers': transfers.map((e) => e.toMap()).toList(),
        'documents': documents.map((e) => e.toMap()).toList(),
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  factory LegalCase.fromMap(Map map) {
    var payments = _list(map['payments'], Payment.fromMap);
    // Records saved before payment tracking only had a running total.
    final legacyReceived = _money(map['feeReceived']);
    if (map['payments'] == null && legacyReceived > 0) {
      payments = [
        Payment(
          id: 'legacy-${_str(map['id'])}',
          date: _date(map['filingDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          amount: legacyReceived,
          note: 'Received before payment tracking',
        ),
      ];
    }
    final type = _str(map['type']);
    return LegalCase(
      id: _str(map['id']),
      type: type.isEmpty ? courtCase : type,
      caseNumber: _str(map['caseNumber']),
      caseTitle: _str(map['caseTitle']),
      clientName: _str(map['clientName']),
      clientContact: _str(map['clientContact']),
      panNumber: _str(map['panNumber']),
      panPassword: _str(map['panPassword']),
      opponentName: _str(map['opponentName']),
      opponentAdvocate: _str(map['opponentAdvocate']),
      court: _str(map['court']),
      judge: _str(map['judge']),
      caseNature: _str(map['caseNature']),
      sections: _str(map['sections']),
      filingDate: _date(map['filingDate']),
      nextHearing: _date(map['nextHearing']),
      hearingPurpose: _str(map['hearingPurpose']),
      notes: _str(map['notes']),
      status: CaseStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => CaseStatus.active),
      disposalResult: map['disposalResult'] == null
          ? null
          : DisposalResult.values.firstWhere((e) => e.name == map['disposalResult'], orElse: () => DisposalResult.allowed),
      disposedOn: _date(map['disposedOn']),
      totalFee: _money(map['totalFee']),
      payments: payments,
      updates: _list(map['updates'], CaseUpdate.fromMap),
      transfers: _list(map['transfers'], CourtTransfer.fromMap),
      documents: _list(map['documents'], CaseDocument.fromMap),
      updatedAt: _date(map['updatedAt']),
    );
  }
}

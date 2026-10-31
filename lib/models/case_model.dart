enum CaseStatus { active, stayed, disposed }
enum DisposalResult { allowed, rejected }

class CaseUpdate {
  final String id;
  final DateTime date;
  final String outcome;
  final DateTime? nextDate;
  final String note;

  const CaseUpdate({
    required this.id,
    required this.date,
    required this.outcome,
    this.nextDate,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'outcome': outcome,
        'nextDate': nextDate?.millisecondsSinceEpoch,
        'note': note,
      };

  factory CaseUpdate.fromMap(Map map) => CaseUpdate(
        id: '${map['id'] ?? ''}',
        date: DateTime.fromMillisecondsSinceEpoch((map['date'] as int?) ?? 0),
        outcome: '${map['outcome'] ?? ''}',
        nextDate: map['nextDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['nextDate'] as int),
        note: '${map['note'] ?? ''}',
      );
}

class CaseDocument {
  final String id;
  final String name;
  final String path;
  final DateTime addedOn;

  const CaseDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.addedOn,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'addedOn': addedOn.millisecondsSinceEpoch,
      };

  factory CaseDocument.fromMap(Map map) => CaseDocument(
        id: '${map['id'] ?? ''}',
        name: '${map['name'] ?? ''}',
        path: '${map['path'] ?? ''}',
        addedOn: DateTime.fromMillisecondsSinceEpoch((map['addedOn'] as int?) ?? 0),
      );
}

class LegalCase {
  final String id;
  final String type;
  final String caseNumber;
  final String caseTitle;
  final String clientName;
  final String clientContact;
  final String opponentName;
  final String opponentAdvocate;
  final String court;
  final String judge;
  final String caseNature;
  final String sections;
  final DateTime? filingDate;
  final DateTime? nextHearing;
  final String hearingPurpose;
  final String notes;
  final CaseStatus status;
  final DisposalResult? disposalResult;
  final DateTime? disposedOn;
  final double totalFee;
  final double feeReceived;
  final List<CaseUpdate> updates;
  final List<CaseDocument> documents;

  const LegalCase({
    required this.id,
    required this.type,
    required this.caseNumber,
    required this.caseTitle,
    required this.clientName,
    required this.clientContact,
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
    this.feeReceived = 0,
    this.updates = const [],
    this.documents = const [],
  });

  double get outstanding => (totalFee - feeReceived).clamp(0, double.infinity);

  LegalCase copyWith({
    String? type,
    String? caseNumber,
    String? caseTitle,
    String? clientName,
    String? clientContact,
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
    double? feeReceived,
    List<CaseUpdate>? updates,
    List<CaseDocument>? documents,
  }) {
    return LegalCase(
      id: id,
      type: type ?? this.type,
      caseNumber: caseNumber ?? this.caseNumber,
      caseTitle: caseTitle ?? this.caseTitle,
      clientName: clientName ?? this.clientName,
      clientContact: clientContact ?? this.clientContact,
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
      feeReceived: feeReceived ?? this.feeReceived,
      updates: updates ?? this.updates,
      documents: documents ?? this.documents,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'caseNumber': caseNumber,
        'caseTitle': caseTitle,
        'clientName': clientName,
        'clientContact': clientContact,
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
        'feeReceived': feeReceived,
        'updates': updates.map((e) => e.toMap()).toList(),
        'documents': documents.map((e) => e.toMap()).toList(),
      };

  factory LegalCase.fromMap(Map map) => LegalCase(
        id: '${map['id'] ?? ''}',
        type: '${map['type'] ?? 'Court Case'}',
        caseNumber: '${map['caseNumber'] ?? ''}',
        caseTitle: '${map['caseTitle'] ?? ''}',
        clientName: '${map['clientName'] ?? ''}',
        clientContact: '${map['clientContact'] ?? ''}',
        opponentName: '${map['opponentName'] ?? ''}',
        opponentAdvocate: '${map['opponentAdvocate'] ?? ''}',
        court: '${map['court'] ?? ''}',
        judge: '${map['judge'] ?? ''}',
        caseNature: '${map['caseNature'] ?? ''}',
        sections: '${map['sections'] ?? ''}',
        filingDate: map['filingDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['filingDate'] as int),
        nextHearing: map['nextHearing'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['nextHearing'] as int),
        hearingPurpose: '${map['hearingPurpose'] ?? ''}',
        notes: '${map['notes'] ?? ''}',
        status: CaseStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => CaseStatus.active),
        disposalResult: map['disposalResult'] == null ? null : DisposalResult.values.firstWhere((e) => e.name == map['disposalResult'], orElse: () => DisposalResult.allowed),
        disposedOn: map['disposedOn'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['disposedOn'] as int),
        totalFee: (map['totalFee'] as num?)?.toDouble() ?? 0,
        feeReceived: (map['feeReceived'] as num?)?.toDouble() ?? 0,
        updates: (map['updates'] as List? ?? []).map((e) => CaseUpdate.fromMap(Map<String, dynamic>.from(e))).toList(),
        documents: (map['documents'] as List? ?? []).map((e) => CaseDocument.fromMap(Map<String, dynamic>.from(e))).toList(),
      );
}

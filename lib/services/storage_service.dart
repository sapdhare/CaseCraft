import 'dart:convert';
import 'dart:io';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/case_model.dart';
import '../models/schedule_model.dart';

class StorageService {
  static const _casesBox = 'casecraft_cases';
  static const _scheduleBox = 'casecraft_schedule';
  static const _settingsBox = 'casecraft_settings';

  late Box _cases;
  late Box _schedule;
  late Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    _cases = await Hive.openBox(_casesBox);
    _schedule = await Hive.openBox(_scheduleBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  List<LegalCase> getCases() => _cases.values
      .map((e) => LegalCase.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();

  List<ScheduleItem> getSchedule() => _schedule.values
      .map((e) => ScheduleItem.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();

  Future<void> saveCase(LegalCase item) => _cases.put(item.id, item.toMap());
  Future<void> deleteCase(String id) => _cases.delete(id);
  Future<void> saveSchedule(ScheduleItem item) => _schedule.put(item.id, item.toMap());
  Future<void> deleteSchedule(String id) => _schedule.delete(id);

  String get practitionerName => (_settings.get('practitionerName') as String?) ?? 'Advocate';
  String get firmName => (_settings.get('firmName') as String?) ?? 'CaseCraft Legal';
  bool get notificationsEnabled => (_settings.get('notificationsEnabled') as bool?) ?? true;

  Future<void> saveProfile({required String practitionerName, required String firmName}) async {
    await _settings.put('practitionerName', practitionerName.trim().isEmpty ? 'Advocate' : practitionerName.trim());
    await _settings.put('firmName', firmName.trim().isEmpty ? 'CaseCraft Legal' : firmName.trim());
  }

  Future<void> setNotificationsEnabled(bool value) => _settings.put('notificationsEnabled', value);

  Future<File> createBackupFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/casecraft_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    final payload = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'profile': {'practitionerName': practitionerName, 'firmName': firmName, 'notificationsEnabled': notificationsEnabled},
      'cases': getCases().map((e) => e.toMap()).toList(),
      'schedule': getSchedule().map((e) => e.toMap()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  Future<int> restoreFromJson(String path) async {
    final file = File(path);
    final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final cases = (map['cases'] as List? ?? []);
    final schedule = (map['schedule'] as List? ?? []);
    await _cases.clear();
    await _schedule.clear();
    for (final item in cases) {
      final c = LegalCase.fromMap(Map<String, dynamic>.from(item));
      await saveCase(c);
    }
    for (final item in schedule) {
      final s = ScheduleItem.fromMap(Map<String, dynamic>.from(item));
      await saveSchedule(s);
    }
    final profile = Map<String, dynamic>.from(map['profile'] as Map? ?? {});
    if (profile['practitionerName'] is String) await _settings.put('practitionerName', profile['practitionerName']);
    if (profile['firmName'] is String) await _settings.put('firmName', profile['firmName']);
    if (profile['notificationsEnabled'] is bool) await _settings.put('notificationsEnabled', profile['notificationsEnabled']);
    return cases.length + schedule.length;
  }
}

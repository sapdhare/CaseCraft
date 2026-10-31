import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/case_model.dart';
import '../models/schedule_model.dart';

/// Local, offline source of truth. Every box is AES-256 encrypted; the key lives in the
/// Android Keystore / iOS Keychain, never next to the data.
class StorageService {
  static const _casesBox = 'casecraft_cases';
  static const _scheduleBox = 'casecraft_schedule';
  static const _settingsBox = 'casecraft_settings';
  static const _keyName = 'casecraft_db_key';
  static const backupVersion = 2;

  final _secure = const FlutterSecureStorage();
  late Box _cases;
  late Box _schedule;
  late Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    final cipher = HiveAesCipher(await _encryptionKey());
    _cases = await _openEncrypted(_casesBox, cipher);
    _schedule = await _openEncrypted(_scheduleBox, cipher);
    _settings = await _openEncrypted(_settingsBox, cipher);
  }

  Future<List<int>> _encryptionKey() async {
    final stored = await _secure.read(key: _keyName);
    if (stored != null) return base64Url.decode(stored);
    final key = Hive.generateSecureKey();
    await _secure.write(key: _keyName, value: base64UrlEncode(key));
    return key;
  }

  /// Opens `<name>_enc`, moving any data from the old unencrypted `<name>` box into it once.
  Future<Box> _openEncrypted(String name, HiveAesCipher cipher) async {
    final box = await Hive.openBox('${name}_enc', encryptionCipher: cipher);
    if (await Hive.boxExists(name)) {
      final plain = await Hive.openBox(name);
      if (box.isEmpty && plain.isNotEmpty) await box.putAll(Map<dynamic, dynamic>.from(plain.toMap()));
      await plain.deleteFromDisk();
    }
    return box;
  }

  List<LegalCase> getCases() => _cases.values
      .whereType<Map>()
      .map((e) => LegalCase.fromMap(Map<String, dynamic>.from(e)))
      .where((c) => c.id.isNotEmpty)
      .toList();

  List<ScheduleItem> getSchedule() => _schedule.values
      .whereType<Map>()
      .map((e) => ScheduleItem.fromMap(Map<String, dynamic>.from(e)))
      .where((s) => s.id.isNotEmpty)
      .toList();

  Future<void> saveCase(LegalCase item) => _cases.put(item.id, item.toMap());
  Future<void> deleteCase(String id) => _cases.delete(id);
  Future<void> saveSchedule(ScheduleItem item) => _schedule.put(item.id, item.toMap());
  Future<void> deleteSchedule(String id) => _schedule.delete(id);

  String get practitionerName => (_settings.get('practitionerName') as String?) ?? 'Advocate';
  String get firmName => (_settings.get('firmName') as String?) ?? 'CaseCraft Legal';
  bool get notificationsEnabled => (_settings.get('notificationsEnabled') as bool?) ?? true;
  bool get appLockEnabled => (_settings.get('appLockEnabled') as bool?) ?? false;

  Future<void> saveProfile({required String practitionerName, required String firmName}) async {
    await _settings.put('practitionerName', practitionerName.trim().isEmpty ? 'Advocate' : practitionerName.trim());
    await _settings.put('firmName', firmName.trim().isEmpty ? 'CaseCraft Legal' : firmName.trim());
  }

  Future<void> setNotificationsEnabled(bool value) => _settings.put('notificationsEnabled', value);
  Future<void> setAppLockEnabled(bool value) => _settings.put('appLockEnabled', value);

  /// Backup leaves the device, so PAN passwords are left out.
  Future<File> createBackupFile() async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/casecraft_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    final payload = {
      'app': 'casecraft',
      'version': backupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'profile': {'practitionerName': practitionerName, 'firmName': firmName, 'notificationsEnabled': notificationsEnabled},
      'cases': getCases().map((e) => e.toMap(includeSecrets: false)).toList(),
      'schedule': getSchedule().map((e) => e.toMap()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file;
  }

  /// Replaces local data with the backup. Validates everything before touching the
  /// database, and keeps PAN passwords already on this device for matching cases.
  Future<int> restoreFromJson(String path) async {
    final file = File(path);
    if (await file.length() > 50 * 1024 * 1024) throw const FormatException('Backup file is too large.');
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['cases'] is! List) throw const FormatException('This is not a CaseCraft backup.');
    final version = decoded['version'];
    if (version is num && version > backupVersion) throw const FormatException('Backup is from a newer CaseCraft version.');

    final existingPasswords = {for (final c in getCases()) c.id: c.panPassword};
    final cases = (decoded['cases'] as List)
        .whereType<Map>()
        .map((e) => LegalCase.fromMap(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty)
        .map((c) => c.panPassword.isEmpty && (existingPasswords[c.id] ?? '').isNotEmpty ? c.copyWith(panPassword: existingPasswords[c.id]) : c)
        .toList();
    final schedule = (decoded['schedule'] is List ? decoded['schedule'] as List : const [])
        .whereType<Map>()
        .map((e) => ScheduleItem.fromMap(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
        .toList();

    await _cases.clear();
    await _schedule.clear();
    await _cases.putAll({for (final c in cases) c.id: c.toMap()});
    await _schedule.putAll({for (final s in schedule) s.id: s.toMap()});
    final profile = decoded['profile'] is Map ? decoded['profile'] as Map : const {};
    if (profile['practitionerName'] is String) await _settings.put('practitionerName', profile['practitionerName']);
    if (profile['firmName'] is String) await _settings.put('firmName', profile['firmName']);
    if (profile['notificationsEnabled'] is bool) await _settings.put('notificationsEnabled', profile['notificationsEnabled']);
    return cases.length + schedule.length;
  }
}

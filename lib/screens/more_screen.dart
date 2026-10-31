import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';
import 'lock_gate.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 90), children: [
      const Text('WORKSPACE', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: gold, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('More', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Row(children: [
          const BrandMark(size: 52),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.practitionerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink)),
            const SizedBox(height: 4),
            Text(s.firmName, style: const TextStyle(color: muted, fontSize: 12)),
          ])),
          IconButton(tooltip: 'Edit profile', onPressed: () => showDialog(context: context, builder: (_) => _ProfileDialog(state: s)), icon: const Icon(Icons.edit_rounded)),
        ]),
      ),
      const SizedBox(height: 18),
      _tile(context, Icons.notifications_active_outlined, 'Reminders', 'Day before, morning of and evening of each hearing. Work offline.', trailing: Switch(value: s.notificationsEnabled, onChanged: (v) => s.setNotifications(v))),
      _tile(context, Icons.fingerprint_rounded, 'App lock', 'Ask for fingerprint, face or phone PIN when CaseCraft opens', trailing: Switch(value: s.appLockEnabled, onChanged: (v) => _setLock(context, s, v))),
      _tile(context, Icons.ios_share_rounded, 'Backup data', 'Export cases, fees and schedule to a file you keep safe', onTap: () => _backup(context)),
      _tile(context, Icons.restore_rounded, 'Restore data', 'Replace this phone\'s data with a CaseCraft backup', onTap: () => _restore(context)),
      _tile(context, Icons.shield_outlined, 'Security & privacy', 'Encrypted on this phone. Nothing is sent online.', onTap: () => _privacy(context)),
      const SizedBox(height: 14),
      const Text('About', style: TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text('CaseCraft 1.1.0', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('A legal command centre designed for focused daily practice management.', style: TextStyle(color: muted, height: 1.4)),
    ]);
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub, {VoidCallback? onTap, Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
            leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: gold.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: gold, size: 21)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: const TextStyle(fontSize: 11.5, color: muted))),
            trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: muted),
          ),
        ),
      );

  void _say(BuildContext context, String message) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setLock(BuildContext context, AppState s, bool on) async {
    if (on && !await deviceCanLock()) {
      if (context.mounted) _say(context, 'Set a screen lock (PIN, pattern or fingerprint) on your phone first.');
      return;
    }
    // Prove it works before relying on it, so nobody locks themselves out.
    if (!await confirmIdentity(on ? 'Turn on App lock' : 'Turn off App lock', allowIfUnsupported: !on)) return;
    await s.setAppLock(on);
  }

  Future<void> _backup(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Create backup'),
        content: const Text('The backup has client names, numbers, PAN and fees, but not income-tax passwords. Save it somewhere only you can open, like your own Drive or a pen drive. Don\'t send it in a chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final file = await context.read<AppState>().storage.createBackupFile();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'CaseCraft Backup'));
    } catch (e) {
      if (context.mounted) _say(context, 'Backup failed: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Cases and schedule on this phone will be replaced with the backup. Take a backup first if you are unsure.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Choose file')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final picked = await FilePicker.pickFile(type: FileType.any);
      final path = picked?.path;
      if (path == null || !context.mounted) return;
      final count = await context.read<AppState>().restoreBackup(path);
      if (context.mounted) _say(context, 'Restored $count records.');
    } on FormatException catch (e) {
      if (context.mounted) _say(context, e.message.isEmpty ? 'That file is not a CaseCraft backup.' : e.message);
    } catch (_) {
      if (context.mounted) _say(context, 'Could not read that file. Nothing was changed.');
    }
  }

  void _privacy(BuildContext context) => showDialog(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Security & privacy'),
          content: const SingleChildScrollView(
            child: Text('• All data is stored only on this phone, encrypted with AES-256. The key is kept in the phone\'s secure hardware.\n'
                '• CaseCraft has no internet permission, so nothing can be sent online.\n'
                '• Income-tax passwords need your fingerprint, face or PIN to view or copy, and are never put in backups. Copied passwords are cleared from the clipboard after 30 seconds.\n'
                '• App lock asks for your fingerprint, face or PIN at launch and after 30 seconds away.\n'
                '• Reminders are set on the phone itself and work without internet.', style: TextStyle(height: 1.45)),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('OK'))],
        ),
      );
}

class _ProfileDialog extends StatefulWidget {
  final AppState state;
  const _ProfileDialog({required this.state});
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final name = TextEditingController(text: widget.state.practitionerName), firm = TextEditingController(text: widget.state.firmName);

  @override
  void dispose() {
    name.dispose();
    firm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Your practice'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: fieldDecoration('Practitioner name')),
          const SizedBox(height: 10),
          TextField(controller: firm, textCapitalization: TextCapitalization.words, decoration: fieldDecoration('Firm / chamber name')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await widget.state.saveProfile(name.text, firm.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      );
}

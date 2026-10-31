import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';

final _auth = LocalAuthentication();

/// Fingerprint / face / device PIN check. True when the user proved it's them.
/// A device with no screen lock can't verify anyone, so it returns [allowIfUnsupported].
Future<bool> confirmIdentity(String reason, {bool allowIfUnsupported = true}) async {
  try {
    if (!await _auth.isDeviceSupported()) return allowIfUnsupported;
    return await _auth.authenticate(localizedReason: reason);
  } catch (_) {
    return false;
  }
}

Future<bool> deviceCanLock() async {
  try {
    return await _auth.isDeviceSupported();
  } catch (_) {
    return false;
  }
}

/// Covers the whole app when App lock is on: at launch and after 30 s in the background.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = context.read<AppState>().appLockEnabled;
  DateTime? _backgroundedAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (!_busy && context.read<AppState>().appLockEnabled && away >= const Duration(seconds: 30)) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    // If the phone's screen lock was removed, don't lock the advocate out of their own data.
    final ok = await confirmIdentity('Unlock CaseCraft');
    _busy = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  // The app stays mounted under the lock so open screens and half-filled forms survive.
  @override
  Widget build(BuildContext context) => Stack(children: [
        ExcludeSemantics(excluding: _locked, child: widget.child),
        if (_locked)
          Positioned.fill(
            child: Material(
              color: ink,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const BrandMark(size: 72),
                  const SizedBox(height: 20),
                  const Text('CaseCraft is locked', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink),
                    onPressed: _unlock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock'),
                  ),
                ]),
              ),
            ),
          ),
      ]);
}

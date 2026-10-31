import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';
import 'lock_gate.dart';

class CaseFormScreen extends StatefulWidget {
  final LegalCase? existing;
  const CaseFormScreen({super.key, this.existing});
  @override
  State<CaseFormScreen> createState() => _CaseFormScreenState();
}

class _CaseFormScreenState extends State<CaseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  String type = courtCase;
  DateTime? filing;
  DateTime? hearing;
  bool _showPassword = false;
  bool _saving = false;

  bool get _court => type == courtCase;
  bool get _tax => type == incomeTaxCase;

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    c = {
      'title': x?.caseTitle ?? '',
      'number': x?.caseNumber ?? '',
      'client': x?.clientName ?? '',
      'clientContact': x?.clientContact ?? '',
      'pan': x?.panNumber ?? '',
      'panPassword': x?.panPassword ?? '',
      'opponent': x?.opponentName ?? '',
      'opponentAdvocate': x?.opponentAdvocate ?? '',
      'court': x?.court ?? '',
      'judge': x?.judge ?? '',
      'nature': x?.caseNature ?? '',
      'sections': x?.sections ?? '',
      'purpose': x?.hearingPurpose ?? '',
      'notes': x?.notes ?? '',
      'totalFee': x == null || x.totalFee == 0 ? '' : _plain(x.totalFee),
      'received': '',
    }.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    filing = x?.filingDate;
    hearing = x?.nextHearing;
    type = x?.type ?? courtCase;
  }

  String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final v in c.values) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final old = widget.existing;
    return Scaffold(
      appBar: AppBar(title: Text(old == null ? 'New case' : 'Edit case')),
      body: Form(
        key: _form,
        // Not a lazy ListView: Form only validates fields that are built, so every field must stay built.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: courtCase, label: Text('Court'), icon: Icon(Icons.account_balance_rounded)),
                  ButtonSegment(value: incomeTaxCase, label: Text('Income Tax'), icon: Icon(Icons.receipt_long_rounded)),
                  ButtonSegment(value: otherMatter, label: Text('Other'), icon: Icon(Icons.assignment_rounded)),
                ],
                selected: {type},
                onSelectionChanged: (v) => setState(() => type = v.first),
              ),
              const SizedBox(height: 22),
              _section('Client'),
              _field('Client name', 'client', required: true, caps: TextCapitalization.words),
              const SizedBox(height: 12),
              _field('Mobile number', 'clientContact', keyboard: TextInputType.phone, validator: (v) => v.isEmpty || isValidPhone(v) ? null : 'Enter a valid phone number'),
              if (_tax) ...[
                const SizedBox(height: 12),
                _field('PAN number', 'pan', required: true, caps: TextCapitalization.characters, maxLength: 10, formatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), _UpperCase()], validator: (v) => isValidPan(v) ? null : 'PAN looks like ABCDE1234F'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: c['panPassword'],
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: fieldDecoration(
                    'Income-tax portal password',
                    hint: 'Stored encrypted on this phone only',
                    suffixIcon: IconButton(tooltip: _showPassword ? 'Hide password' : 'Show password', icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: _togglePassword),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _section(_tax ? 'Income-tax matter' : 'Case'),
              _field(_tax ? 'Matter title' : 'Case title', 'title', required: true, hint: _tax ? 'ITR AY 2025-26 / Notice u/s 143(2)' : 'Sharma v. State', caps: TextCapitalization.sentences),
              const SizedBox(height: 12),
              _field(_tax ? 'Reference / notice no.' : 'Case number', 'number'),
              const SizedBox(height: 12),
              _field(
                _court
                    ? 'Case type'
                    : _tax
                    ? 'Matter type'
                    : 'Nature',
                'nature',
                hint: _court
                    ? 'Civil suit, bail, writ…'
                    : _tax
                    ? 'ITR filing, scrutiny, appeal…'
                    : null,
                caps: TextCapitalization.sentences,
              ),
              if (_court) ...[const SizedBox(height: 12), _field('Opposite party', 'opponent', caps: TextCapitalization.words), const SizedBox(height: 12), _field('Opposing advocate', 'opponentAdvocate', caps: TextCapitalization.words), const SizedBox(height: 12), _field('Sections / laws', 'sections')],
              const SizedBox(height: 22),
              _section(
                _court
                    ? 'Court & hearing'
                    : _tax
                    ? 'Department & dates'
                    : 'Forum & dates',
              ),
              _field(
                _court
                    ? 'Court (where the case is running)'
                    : _tax
                    ? 'Ward / circle / office'
                    : 'Forum',
                'court',
                required: _court,
                caps: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _field(
                _court
                    ? 'Judge'
                    : _tax
                    ? 'Assessing officer'
                    : 'Authority',
                'judge',
                caps: TextCapitalization.words,
              ),
              if (old != null && _court)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text('Moved to another court? Use Transfer on the case page to keep the history.', style: TextStyle(fontSize: 11.5, color: muted)),
                ),
              const SizedBox(height: 12),
              _field(_tax ? 'Next step / purpose' : 'Hearing purpose', 'purpose', caps: TextCapitalization.sentences),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dateTile(_tax ? 'Filed / received' : 'Filing date', filing, (d) => setState(() => filing = d), onClear: () => setState(() => filing = null))),
                  const SizedBox(width: 12),
                  Expanded(child: _dateTile(_tax ? 'Next date' : 'Next hearing', hearing, (d) => setState(() => hearing = d), onClear: () => setState(() => hearing = null))),
                ],
              ),
              const SizedBox(height: 22),
              _section('Fees'),
              _field('Fee quoted to client', 'totalFee', keyboard: const TextInputType.numberWithOptions(decimal: true), prefix: '₹ ', validator: _amountValidator),
              const SizedBox(height: 12),
              if (old == null) _field('Received now (optional)', 'received', keyboard: const TextInputType.numberWithOptions(decimal: true), prefix: '₹ ', validator: _amountValidator) else Text('Received so far ${rupees(old.feeReceived)} • add more payments from the case page.', style: const TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 22),
              _section('Notes'),
              _field('Practice notes', 'notes', maxLines: 5, caps: TextCapitalization.sentences),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                label: Text(old == null ? 'Save case' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _amountValidator(String v) => v.isEmpty || parseAmount(v) != null ? null : 'Enter a valid amount';

  Widget _section(String x) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      x,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink),
    ),
  );

  Widget _field(String label, String key, {bool required = false, int maxLines = 1, TextInputType? keyboard, String? hint, String? prefix, int? maxLength, TextCapitalization caps = TextCapitalization.none, List<TextInputFormatter>? formatters, String? Function(String)? validator}) => TextFormField(
    controller: c[key],
    maxLines: maxLines,
    maxLength: maxLength,
    keyboardType: keyboard,
    textCapitalization: caps,
    inputFormatters: formatters,
    decoration: fieldDecoration(required ? '$label *' : label, hint: hint).copyWith(prefixText: prefix, counterText: ''),
    validator: (raw) {
      final v = (raw ?? '').trim();
      if (required && v.isEmpty) return 'Required';
      return validator?.call(v);
    },
  );

  Widget _dateTile(String label, DateTime? value, ValueChanged<DateTime> onPick, {required VoidCallback onClear}) => InkWell(
    onTap: () async {
      final d = await showDatePicker(context: context, firstDate: DateTime(1990), lastDate: DateTime(2100), initialDate: value ?? DateTime.now());
      if (d != null) onPick(d);
    },
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 6, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fmtDate(value),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
                ),
              ),
              if (value != null)
                InkWell(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded, size: 16, color: muted),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _togglePassword() async {
    if (!_showPassword && c['panPassword']!.text.isNotEmpty && !await confirmIdentity('Show the saved password')) return;
    if (mounted) setState(() => _showPassword = !_showPassword);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the highlighted fields.')));
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final old = widget.existing;
    String t(String k) => c[k]!.text.trim();
    final received = parseAmount(t('received')) ?? 0;
    final base =
        old ??
        LegalCase(
          id: state.newId(),
          type: type,
          caseNumber: '',
          caseTitle: '',
          clientName: '',
          clientContact: '',
          opponentName: '',
          opponentAdvocate: '',
          court: '',
          judge: '',
          caseNature: '',
          sections: '',
          hearingPurpose: '',
          notes: '',
          payments: [if (received > 0) Payment(id: state.newId(), date: DateTime.now(), amount: received, note: 'Received at engagement')],
        );
    final item = LegalCase(
      id: base.id,
      type: type,
      caseNumber: t('number'),
      caseTitle: t('title'),
      clientName: t('client'),
      clientContact: t('clientContact'),
      // PAN fields belong to income-tax matters only.
      panNumber: _tax ? t('pan').toUpperCase() : '',
      panPassword: _tax ? c['panPassword']!.text : '',
      opponentName: _court ? t('opponent') : '',
      opponentAdvocate: _court ? t('opponentAdvocate') : '',
      court: t('court'),
      judge: t('judge'),
      caseNature: t('nature'),
      sections: _court ? t('sections') : '',
      filingDate: filing,
      nextHearing: hearing,
      hearingPurpose: t('purpose'),
      notes: t('notes'),
      status: base.status,
      disposalResult: base.disposalResult,
      disposedOn: base.disposedOn,
      totalFee: parseAmount(t('totalFee')) ?? 0,
      payments: base.payments,
      updates: base.updates,
      transfers: base.transfers,
      documents: base.documents,
    );
    try {
      await state.upsertCase(item);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}

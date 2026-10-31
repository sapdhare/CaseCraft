import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';
import 'case_form_screen.dart';
import 'lock_gate.dart';

class CaseDetailScreen extends StatelessWidget {
  final LegalCase item;
  const CaseDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AppState>().cases.firstWhere((c) => c.id == item.id, orElse: () => item);
    final open = current.status != CaseStatus.disposed;
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Edit', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseFormScreen(existing: current))), icon: const Icon(Icons.edit_rounded)),
        PopupMenuButton<String>(onSelected: (v) { if (v == 'delete') _delete(context, current); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete case'))]),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 36), children: [
        _hero(current),
        const SizedBox(height: 14),
        _summary(current),
        if (open) ...[const SizedBox(height: 14), _actions(context, current)],
        const SizedBox(height: 14),
        _FeesCard(item: current),
        if (current.transfers.isNotEmpty) ...[const SizedBox(height: 14), _transfers(current)],
        const SizedBox(height: 14),
        _timeline(current),
      ]),
    );
  }

  Widget _hero(LegalCase c) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(c.caseTitle, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.07))),
            StatusPill(c.status == CaseStatus.disposed ? (c.disposalResult == DisposalResult.allowed ? 'Allowed' : 'Rejected') : 'Active', color: c.status == CaseStatus.disposed ? const Color(0xFF7EB38E) : gold),
          ]),
          const SizedBox(height: 8),
          Text([c.isIncomeTax ? 'Income Tax' : c.isCourtCase ? 'Court case' : 'Matter', c.caseNumber, c.clientName, c.opponentName].where((x) => x.isNotEmpty).join(' • '), style: TextStyle(color: Colors.white.withValues(alpha: .68), fontSize: 12)),
        ]),
      );

  Widget _summary(LegalCase c) {
    final hearing = c.nextHearing == null ? 'Not set' : '${fmtDate(c.nextHearing)}${c.hearingPurpose.isEmpty ? '' : ' • ${c.hearingPurpose}'}';
    return SurfaceCard(
      child: Column(children: [
        _row(Icons.person_outline_rounded, 'Client', c.clientName),
        _row(Icons.phone_outlined, 'Mobile', c.clientContact),
        if (c.isIncomeTax) ...[
          _row(Icons.badge_outlined, 'PAN', c.panNumber),
          _SecretRow(value: c.panPassword),
          _row(Icons.account_balance_rounded, 'Ward / office', c.court),
          _row(Icons.person_pin_outlined, 'Officer', c.judge),
          _row(Icons.category_outlined, 'Matter type', c.caseNature),
          _row(Icons.event_rounded, 'Next date', hearing),
        ] else ...[
          _row(Icons.category_outlined, 'Case type', c.caseNature),
          _row(Icons.account_balance_rounded, 'Court', c.court),
          _row(Icons.gavel_rounded, 'Judge', c.judge),
          if (c.isCourtCase) _row(Icons.menu_book_rounded, 'Sections', c.sections),
          _row(Icons.event_rounded, 'Next hearing', hearing),
        ],
        if (c.notes.isNotEmpty) _row(Icons.notes_rounded, 'Notes', c.notes),
      ]),
    );
  }

  Widget _actions(BuildContext context, LegalCase c) => Column(children: [
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _sheet(context, _UpdateSheet(item: c)), icon: const Icon(Icons.bolt_rounded), label: const Text('Update case'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => _sheet(context, _TransferSheet(item: c)), icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Transfer'))),
        ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _dispose(context, c), icon: const Icon(Icons.verified_rounded), label: const Text('Dispose case'))),
      ]);

  Widget _transfers(LegalCase c) {
    final list = [...c.transfers]..sort((a, b) => b.date.compareTo(a.date));
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Court transfers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink)),
        for (final t in list)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.swap_horiz_rounded, size: 19, color: gold),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fmtDate(t.date), style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${t.fromCourt.isEmpty ? 'Not set' : t.fromCourt}  →  ${t.toCourt}', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                if (t.fromJudge.isNotEmpty || t.toJudge.isNotEmpty) Text('Judge: ${t.fromJudge.isEmpty ? '—' : t.fromJudge} → ${t.toJudge.isEmpty ? '—' : t.toJudge}', style: const TextStyle(fontSize: 12, color: muted)),
                if (t.reason.isNotEmpty) Text(t.reason, style: const TextStyle(fontSize: 12, color: muted)),
              ])),
            ]),
          ),
      ]),
    );
  }

  Widget _timeline(LegalCase c) {
    final updates = [...c.updates]..sort((a, b) => b.date.compareTo(a.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(left: 3, bottom: 10), child: Text('Case history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink))),
      if (updates.isEmpty)
        const SurfaceCard(child: Text('No updates recorded yet. Use Update case after each hearing to build a reliable history.', style: TextStyle(color: muted, height: 1.45)))
      else
        ...updates.map((u) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: const BoxDecoration(color: gold, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fmtDay(u.date), style: const TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(u.outcome, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
                    if (u.nextDate != null) ...[const SizedBox(height: 4), Text('Next date: ${fmtDate(u.nextDate)}', style: const TextStyle(fontSize: 12, color: muted))],
                    if (u.note.isNotEmpty) ...[const SizedBox(height: 7), Text(u.note, style: const TextStyle(color: muted, height: 1.35))],
                  ])),
                ]),
              ),
            )),
    ]);
  }

  Future<void> _dispose(BuildContext context, LegalCase c) async {
    final choice = await showDialog<DisposalResult>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Dispose case'),
        content: const Text('Choose the final result recorded in CaseCraft.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.pop(dialog, DisposalResult.rejected), child: const Text('Rejected')),
          FilledButton(onPressed: () => Navigator.pop(dialog, DisposalResult.allowed), child: const Text('Allowed')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    await context.read<AppState>().disposeCase(c, choice);
  }

  Future<void> _delete(BuildContext context, LegalCase c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete case?'),
        content: const Text('This permanently removes the case, its fees and its history from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: danger), onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().deleteCase(c);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

Widget _row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: gold),
        const SizedBox(width: 12),
        SizedBox(width: 105, child: Text(label, style: const TextStyle(fontSize: 12, color: muted))),
        Expanded(child: SelectableText(value.isEmpty ? 'Not set' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink))),
      ]),
    );

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => child);

/// Padding + scroll so a bottom sheet stays above the keyboard on small phones.
class _SheetBody extends StatelessWidget {
  final List<Widget> children;
  const _SheetBody({required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      );
}

Widget _sheetTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink)));

Widget _dateRow(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPick, {DateTime? first}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(fmtDate(value)),
      trailing: const Icon(Icons.calendar_month_rounded, color: gold),
      onTap: () async {
        final start = first ?? DateTime(1990);
        final initial = value == null || value.isBefore(start) ? (DateTime.now().isBefore(start) ? start : DateTime.now()) : value;
        final d = await showDatePicker(context: context, firstDate: start, lastDate: DateTime(2100), initialDate: initial);
        if (d != null) onPick(d);
      },
    );

class _SecretRow extends StatefulWidget {
  final String value;
  const _SecretRow({required this.value});
  @override
  State<_SecretRow> createState() => _SecretRowState();
}

class _SecretRowState extends State<_SecretRow> {
  bool _shown = false;

  Future<void> _toggle() async {
    if (!_shown && !await confirmIdentity('Show the client\'s password')) return;
    if (mounted) setState(() => _shown = !_shown);
  }

  Future<void> _copy() async {
    if (!await confirmIdentity('Copy the client\'s password')) return;
    final secret = widget.value;
    await Clipboard.setData(ClipboardData(text: secret));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password copied. Clipboard clears in 30 seconds.')));
    Timer(const Duration(seconds: 30), () async {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == secret) await Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return _row(Icons.key_outlined, 'IT password', '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        const Icon(Icons.key_outlined, size: 19, color: gold),
        const SizedBox(width: 12),
        const SizedBox(width: 105, child: Text('IT password', style: TextStyle(fontSize: 12, color: muted))),
        Expanded(child: Text(_shown ? widget.value : '••••••••', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink))),
        IconButton(visualDensity: VisualDensity.compact, tooltip: _shown ? 'Hide' : 'Show', onPressed: _toggle, icon: Icon(_shown ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19)),
        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Copy', onPressed: _copy, icon: const Icon(Icons.copy_rounded, size: 18)),
      ]),
    );
  }
}

class _FeesCard extends StatelessWidget {
  final LegalCase item;
  const _FeesCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final payments = [...item.payments]..sort((a, b) => b.date.compareTo(a.date));
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Fees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink))),
          TextButton.icon(onPressed: () => _sheet(context, _PaymentSheet(item: item)), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add payment')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _figure('Quoted', item.totalFee, ink),
          _figure('Received', item.feeReceived, success),
          item.excessReceived > 0 ? _figure('Extra paid', item.excessReceived, gold) : _figure('Remaining', item.outstanding, item.outstanding > 0 ? danger : success),
        ]),
        if (payments.isNotEmpty) ...[
          const Divider(height: 26),
          for (final p in payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.payments_outlined, size: 18, color: success),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rupees(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
                  Text([fmtDate(p.date), if (p.note.isNotEmpty) p.note].join(' • '), style: const TextStyle(fontSize: 11.5, color: muted)),
                ])),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'Remove payment', onPressed: () => _remove(context, p), icon: const Icon(Icons.delete_outline_rounded, size: 19, color: muted)),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _figure(String label, double value, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(rupees(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color))),
        ]),
      );

  Future<void> _remove(BuildContext context, Payment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove payment?'),
        content: Text('${rupees(p.amount)} received on ${fmtDate(p.date)} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && context.mounted) await context.read<AppState>().deletePayment(item, p.id);
  }
}

class _UpdateSheet extends StatefulWidget {
  final LegalCase item;
  const _UpdateSheet({required this.item});
  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  final outcome = TextEditingController(), note = TextEditingController(), amount = TextEditingController();
  late DateTime? next = widget.item.nextHearing != null && widget.item.nextHearing!.isAfter(DateTime.now()) ? widget.item.nextHearing : null;
  bool saving = false;

  @override
  void dispose() {
    outcome.dispose();
    note.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final paid = amount.text.trim().isEmpty ? 0.0 : parseAmount(amount.text);
    if (outcome.text.trim().isEmpty) return _say('Write what happened today.');
    if (paid == null) return _say('Enter a valid amount, or leave it empty.');
    setState(() => saving = true);
    await context.read<AppState>().addUpdate(widget.item, outcome: outcome.text.trim(), nextDate: next, note: note.text.trim(), amountReceived: paid);
    if (mounted) Navigator.pop(context);
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) => _SheetBody(children: [
        _sheetTitle('Update today'),
        TextField(controller: outcome, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: fieldDecoration('What happened today *', hint: 'Arguments, order, adjournment, compliance…')),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: fieldDecoration('Notes')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: fieldDecoration('Money received today (optional)').copyWith(prefixText: '₹ ')),
        const SizedBox(height: 4),
        _dateRow(context, 'Next hearing date', next, (d) => setState(() => next = d), first: DateTime.now()),
        if (next != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => next = null), child: const Text('No next date'))),
        const SizedBox(height: 8),
        FilledButton(onPressed: saving ? null : _save, child: const SizedBox(width: double.infinity, child: Center(child: Text('Save update')))),
      ]);
}

class _PaymentSheet extends StatefulWidget {
  final LegalCase item;
  const _PaymentSheet({required this.item});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final amount = TextEditingController(), note = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseAmount(amount.text);
    if (value == null || value == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the amount received.')));
      return;
    }
    setState(() => saving = true);
    await context.read<AppState>().addPayment(widget.item, amount: value, date: date, note: note.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetBody(children: [
        _sheetTitle('Payment received'),
        Text('Remaining before this: ${rupees(widget.item.outstanding)}', style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: fieldDecoration('Amount *').copyWith(prefixText: '₹ ')),
        const SizedBox(height: 12),
        TextField(controller: note, textCapitalization: TextCapitalization.sentences, decoration: fieldDecoration('Note', hint: 'Cash, UPI, cheque no…')),
        _dateRow(context, 'Received on', date, (d) => setState(() => date = d)),
        const SizedBox(height: 8),
        FilledButton(onPressed: saving ? null : _save, child: const SizedBox(width: double.infinity, child: Center(child: Text('Save payment')))),
      ]);
}

class _TransferSheet extends StatefulWidget {
  final LegalCase item;
  const _TransferSheet({required this.item});
  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final court = TextEditingController(), judge = TextEditingController(), reason = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    court.dispose();
    judge.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final to = court.text.trim();
    if (to.isEmpty || to.toLowerCase() == widget.item.court.trim().toLowerCase() && judge.text.trim() == widget.item.judge.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the new court.')));
      return;
    }
    setState(() => saving = true);
    await context.read<AppState>().transferCase(widget.item, toCourt: to, toJudge: judge.text.trim(), date: date, reason: reason.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _SheetBody(children: [
        _sheetTitle('Transfer case'),
        Text('Now at: ${widget.item.court.isEmpty ? 'Not set' : widget.item.court}${widget.item.judge.isEmpty ? '' : ' • ${widget.item.judge}'}', style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        TextField(controller: court, autofocus: true, textCapitalization: TextCapitalization.words, decoration: fieldDecoration('New court *')),
        const SizedBox(height: 12),
        TextField(controller: judge, textCapitalization: TextCapitalization.words, decoration: fieldDecoration('New judge')),
        const SizedBox(height: 12),
        TextField(controller: reason, textCapitalization: TextCapitalization.sentences, decoration: fieldDecoration('Reason / order', hint: 'Transfer order, jurisdiction…')),
        _dateRow(context, 'Transferred on', date, (d) => setState(() => date = d)),
        const SizedBox(height: 8),
        FilledButton(onPressed: saving ? null : _save, child: const SizedBox(width: double.infinity, child: Center(child: Text('Save transfer')))),
      ]);
}

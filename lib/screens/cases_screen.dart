import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/case_model.dart';
import '../state/app_state.dart';
import '../widgets/app_ui.dart';
import 'case_detail_screen.dart';
import 'case_form_screen.dart';

class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.visibleCases;
    return CustomScrollView(slivers: [SliverToBoxAdapter(child: AppPageHeader(eyebrow: 'Practice', title: 'Your cases', subtitle: '${s.activeCount} active matters • ${s.disposedCount} disposed', actions: [IconButton(onPressed: () => showSearch(context: context, delegate: _CaseSearchDelegate()), icon: const Icon(Icons.search_rounded))])), SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 8), child: Row(children: [for (final f in CaseStatusFilter.values) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f == CaseStatusFilter.active ? 'Active' : f == CaseStatusFilter.disposed ? 'Disposed' : 'All'), selected: s.filter == f, onSelected: (_) => s.setFilter(f)))),]))), if (list.isEmpty) SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.folder_open_rounded, title: s.cases.isEmpty ? 'Start building your case desk' : 'No cases here', message: 'Create a court case or matter, then let CaseCraft handle dates, history and reminders.', actionLabel: 'Add case', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseFormScreen())))) else SliverPadding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), sliver: SliverList.builder(itemCount: list.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _CaseCard(item: list[i])))), SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 90), child: Center(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseFormScreen())), icon: const Icon(Icons.add_rounded), label: const Text('Add new case'))))) ]);
  }
}

class _CaseCard extends StatelessWidget { final LegalCase item; const _CaseCard({required this.item}); @override Widget build(BuildContext context) => SurfaceCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailScreen(item: item))), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: item.status == CaseStatus.disposed ? success.withValues(alpha: .10) : gold.withValues(alpha: .11), borderRadius: BorderRadius.circular(16)), child: Icon(item.status == CaseStatus.disposed ? Icons.verified_rounded : Icons.folder_rounded, color: item.status == CaseStatus.disposed ? success : gold)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(item.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: ink))), StatusPill(item.status == CaseStatus.disposed ? (item.disposalResult == DisposalResult.allowed ? 'Allowed' : 'Rejected') : 'Active', color: item.status == CaseStatus.disposed ? success : gold)]), const SizedBox(height: 6), Text([if (item.isIncomeTax) 'Income Tax', item.caseNumber, item.clientName, item.court].where((e) => e.isNotEmpty).join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted)), const SizedBox(height: 10), Row(children: [Icon(Icons.event_outlined, size: 15, color: gold), const SizedBox(width: 5), Expanded(child: Text(item.nextHearing == null ? 'No next date' : 'Next: ${fmtDate(item.nextHearing)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink))), if (item.outstanding > 0) Flexible(child: Text('${rupees(item.outstanding)} due', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: danger, fontWeight: FontWeight.w800)))])]))])); }

class _CaseSearchDelegate extends SearchDelegate<String> {
  _CaseSearchDelegate() : super(searchFieldLabel: 'Case, client, PAN, court…');
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));
  @override
  Widget buildResults(BuildContext context) => _results(context);
  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    if (query.trim().isEmpty) return const Center(child: Text('Search by case, client, mobile, PAN, court, section or opponent.', textAlign: TextAlign.center));
    final hits = context.watch<AppState>().searchCases(query);
    if (hits.isEmpty) return const Center(child: Text('No matching cases.'));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(20, 14, 20, 30), itemCount: hits.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _CaseCard(item: hits[i])));
  }
}

import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'cases_screen.dart';
import 'schedule_screen.dart';
import 'more_screen.dart';
import '../widgets/app_ui.dart';

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [DashboardScreen(), CasesScreen(), ScheduleScreen(), MoreScreen()];
  final labels = const ['Overview', 'Cases', 'Schedule', 'More'];
  final icons = const [Icons.grid_view_rounded, Icons.folder_copy_rounded, Icons.calendar_month_rounded, Icons.more_horiz_rounded];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    if (wide) {
      return Scaffold(body: Row(children: [Container(width: 92, color: ink, child: Column(children: [const SizedBox(height: 24), const BrandMark(size: 48), const SizedBox(height: 32), for (int i = 0; i < labels.length; i++) _railItem(i)],)), Expanded(child: IndexedStack(index: index, children: pages))]));
    }
    return Scaffold(body: IndexedStack(index: index, children: pages), bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(icons[i]), selectedIcon: Icon(icons[i]), label: labels[i]))));
  }
  Widget _railItem(int i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: IconButton(onPressed: () => setState(() => index = i), style: IconButton.styleFrom(backgroundColor: index == i ? gold.withValues(alpha: .18) : Colors.transparent), icon: Icon(icons[i], color: index == i ? gold : Colors.white70)));
}

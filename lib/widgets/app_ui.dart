import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const ink = Color(0xFF102033);
const gold = Color(0xFFC9A66B);
const canvas = Color(0xFFF6F3ED);
const paper = Color(0xFFFFFFFF);
const muted = Color(0xFF6A7280);
const success = Color(0xFF4F7D62);
const danger = Color(0xFFB65B5B);

String fmtDate(DateTime? d) => d == null ? 'Not set' : DateFormat('dd MMM yyyy').format(d);
String fmtDay(DateTime d) => DateFormat('EEE, dd MMM').format(d);
String rupees(num n) => '₹${n.toStringAsFixed(0)}';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(size * .28),
          boxShadow: [BoxShadow(color: ink.withValues(alpha: .14), blurRadius: 16, offset: const Offset(0, 7))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(size * .28), child: Image.asset('assets/casecraft_logo.png', width: size, height: size, fit: BoxFit.cover)),
      );
}

class SurfaceCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry padding; final VoidCallback? onTap;
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});
  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(24), border: Border.all(color: ink.withValues(alpha: .05)), boxShadow: [BoxShadow(color: ink.withValues(alpha: .035), blurRadius: 26, offset: const Offset(0, 9))]),
      child: child,
    );
    return onTap == null ? content : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: content);
  }
}

class MetricTile extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color accent;
  const MetricTile({super.key, required this.label, required this.value, required this.icon, required this.accent});
  @override
  Widget build(BuildContext context) => SurfaceCard(padding: const EdgeInsets.all(17), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent, size: 22)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11.5, color: muted, fontWeight: FontWeight.w600))]))]));
}

class StatusPill extends StatelessWidget {
  final String label; final Color color;
  const StatusPill(this.label, {super.key, this.color = gold});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(999)), child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)));
}

class AppPageHeader extends StatelessWidget {
  final String eyebrow; final String title; final String? subtitle; final List<Widget> actions;
  const AppPageHeader({super.key, required this.eyebrow, required this.title, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.4, color: gold, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: ink, height: 1.05)), if (subtitle != null) ...[const SizedBox(height: 7), Text(subtitle!, style: const TextStyle(color: muted, height: 1.35))]])), ...actions]));
}

InputDecoration fieldDecoration(String label, {String? hint, Widget? suffixIcon}) => InputDecoration(labelText: label, hintText: hint, suffixIcon: suffixIcon, filled: true, fillColor: paper, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: ink.withValues(alpha: .07))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: ink.withValues(alpha: .07))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: gold, width: 1.5)), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15));

class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String message; final VoidCallback? onAction; final String? actionLabel;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.onAction, this.actionLabel});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(36), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 68, height: 68, decoration: BoxDecoration(color: gold.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(icon, color: gold, size: 30)), const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.45)), if (onAction != null) ...[const SizedBox(height: 18), FilledButton(onPressed: onAction, child: Text(actionLabel ?? 'Add'))]])));
}

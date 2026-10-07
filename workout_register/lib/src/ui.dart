import 'package:flutter/material.dart';

const accent = Color(0xFFCDF582);
const muted = Color(0xFFA6AFA3);
const background = Color(0xFF111510);
const surface = Color(0xFF1D231C);

class CompletionToggle extends StatelessWidget {
  const CompletionToggle({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    child: TextButton.icon(
      onPressed: onSelected == null ? null : () => onSelected!(!selected),
      icon: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      label: label,
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFF30392D)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: child,
    ),
  );
}

class PageContent extends StatelessWidget {
  const PageContent({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: children,
      ),
    ),
  );
}

String number(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1).replaceAll('.', ',');
String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String timestamp(DateTime date) {
  final local = date.toLocal();
  return '${dateLabel(local)}/${local.year} às ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

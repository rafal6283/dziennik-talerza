import 'package:flutter/material.dart';

import '../calc.dart';

const _months = ['stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca', 'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'];
const _wd = ['poniedziałek', 'wtorek', 'środa', 'czwartek', 'piątek', 'sobota', 'niedziela'];
const _wdShort = ['pn', 'wt', 'śr', 'cz', 'pt', 'sb', 'nd'];

DateTime _d(String iso) => DateTime.parse('${iso}T12:00:00');

String dayLabel(String iso) {
  final t = todayIso();
  if (iso == t) return 'Dziś';
  if (iso == shiftDay(t, -1)) return 'Wczoraj';
  final d = _d(iso);
  return '${_wd[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

String shortDay(String iso) => _wdShort[_d(iso).weekday - 1];
int dayOfMonth(String iso) => _d(iso).day;

/// Parsuje liczbę wpisaną po polsku: "1 234,5" albo "1234.5".
double? parseNum(String s) {
  final t = s.trim().replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String numInput(double v) {
  if (v == 0) return '';
  var s = v.toStringAsFixed(1);
  s = s.replaceFirst(RegExp(r'\.0$'), '');
  return s.replaceAll('.', ',');
}

class Palette {
  static const seed = Color(0xFF2E7650);
  static const board = Color(0xFF121815);
  static const boardDim = Color(0xFF9AA79F);

  static bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color good(BuildContext c) => _dark(c) ? const Color(0xFF6FC497) : const Color(0xFF2E7650);
  static Color bad(BuildContext c) => _dark(c) ? const Color(0xFFEE8577) : const Color(0xFFB33A2E);
  static Color amber(BuildContext c) => _dark(c) ? const Color(0xFFF0A55A) : const Color(0xFFC26A12);
  static Color sunk(BuildContext c) => Theme.of(c).colorScheme.surfaceContainerHighest;

  static Color comfort(BuildContext c, int? v) {
    if (v == null || v == 0) return sunk(c);
    if (v >= 4) return good(c);
    if (v == 3) return amber(c);
    return bad(c);
  }

  static Color severity(BuildContext c, int sev) => sev <= 1 ? amber(c) : bad(c);
}

const tabular = [FontFeature.tabularFigures()];

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'Usuń', bool destructive = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error, foregroundColor: Theme.of(c).colorScheme.onError) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pastylka z tekstem (objaw, ocena).
class Chip2 extends StatelessWidget {
  final String text;
  final Color? color;
  final bool solid;
  const Chip2(this.text, {super.key, this.color, this.solid = false});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? c : (color == null ? Palette.sunk(context) : c.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: TextStyle(color: solid ? Theme.of(context).colorScheme.surface : c, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 6),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Karta z marginesami używana na wszystkich ekranach.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        child: Padding(padding: padding, child: child),
      );
}

/// Pozioma skala 1–5 (energia, sytość, komfort).
class ScalePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final List<String>? labels;
  const ScalePicker({super.key, required this.value, required this.onChanged, this.labels});
  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
        segments: [for (var i = 1; i <= 5; i++) ButtonSegment(value: i, label: Text(labels != null ? '$i\n${labels![i]}' : '$i', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))],
        selected: value == 0 ? {} : {value},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.isEmpty ? 0 : s.first),
      );
}

class Meter extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  const Meter(this.fraction, this.color, {super.key, this.height = 8});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: fraction.clamp(0, 1), minHeight: height, color: color, backgroundColor: Palette.sunk(context)),
      );
}

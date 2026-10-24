import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calc.dart';
import '../models.dart';
import 'format.dart';

/// Wspólne efekty wykresów: animacja wejścia (ponawiana przy zmianie danych),
/// wybór elementu dotknięciem lub przeciągnięciem palca, dymek z wartością
/// i delikatna wibracja przy przeskoku na kolejny element.

/// Kaskada: postęp i-tego z n elementów przy globalnym postępie [t] (0→1), z wygładzeniem ease-out.
double stagger(double t, int i, int n, {double spread = 0.35}) {
  final delay = n <= 1 ? 0.0 : spread * i / (n - 1);
  final p = ((t - delay) / (1 - spread)).clamp(0.0, 1.0);
  final q = 1 - p;
  return 1 - q * q * q;
}

/// Buduje malarza dla bieżącego stanu: [t] postęp wejścia 0→1, [sel] wybrany indeks
/// (zostaje ustawiony także podczas znikania dymka), [selA] widoczność wyboru 0→1.
typedef ChartPainterBuilder = CustomPainter Function(double t, int? sel, double selA);

class InteractiveChart extends StatefulWidget {
  final double height;

  /// Zmiana klucza = dane się zmieniły → animacja wejścia od nowa.
  final Object? dataKey;
  final int count;

  /// Który element jest pod palcem (null = żaden).
  final int? Function(Offset p, Size size) indexAt;
  final ChartPainterBuilder painter;
  final Duration duration;
  final bool animate;
  final ValueChanged<int?>? onSelect;

  const InteractiveChart({
    super.key,
    required this.height,
    required this.dataKey,
    required this.count,
    required this.indexAt,
    required this.painter,
    this.duration = const Duration(milliseconds: 850),
    this.animate = true,
    this.onSelect,
  });

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: widget.duration);
  late final AnimationController _sel = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 170), reverseDuration: const Duration(milliseconds: 240));
  int? _idx;
  int? _last;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _in.forward();
    } else {
      _in.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveChart old) {
    super.didUpdateWidget(old);
    if (old.dataKey != widget.dataKey) {
      if (widget.animate) _in.forward(from: 0);
      if (old.count != widget.count) {
        _idx = null;
        _last = null;
        _sel.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _sel.dispose();
    super.dispose();
  }

  void _pick(int? i) {
    if (i != null && (i < 0 || i >= widget.count)) i = null;
    if (i == _idx) return;
    setState(() {
      _idx = i;
      if (i != null) {
        _last = i;
        _sel.forward();
        HapticFeedback.selectionClick();
      } else {
        _sel.reverse();
      }
    });
    widget.onSelect?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, widget.height);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final i = widget.indexAt(d.localPosition, size);
          _pick(i == _idx ? null : i);
        },
        onHorizontalDragStart: (d) => _pick(widget.indexAt(d.localPosition, size)),
        onHorizontalDragUpdate: (d) => _pick(widget.indexAt(d.localPosition, size)),
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _sel]),
          builder: (context, _) => CustomPaint(
            size: size,
            painter: widget.painter(_in.value, _last, _sel.value),
          ),
        ),
      );
    });
  }
}

/// Dymek z tekstem nad punktem ([x], [y]); dosuwany do krawędzi. Opcjonalnie pionowa linia pomocnicza.
void paintTip(
  Canvas c,
  Size size,
  String text,
  double x,
  double y,
  double a, {
  Color bg = const Color(0xFFF2F2F7),
  Color fg = const Color(0xFF111118),
  double? guideTop,
  double? guideBottom,
  Color guide = const Color(0x66FFFFFF),
}) {
  if (a <= 0) return;
  if (guideTop != null && guideBottom != null) {
    c.drawLine(Offset(x, guideTop), Offset(x, guideBottom),
        Paint()
          ..color = guide.withValues(alpha: guide.a * a)
          ..strokeWidth = 1);
  }
  final tp = TextPainter(
    text: TextSpan(
        text: text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg.withValues(alpha: a))),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: size.width - 16);
  const padH = 8.0, padV = 5.0;
  final w = tp.width + 2 * padH;
  final h = tp.height + 2 * padV;
  final lift = 6 * (1 - a);
  final left = (x - w / 2).clamp(0.0, (size.width - w).clamp(0.0, double.infinity)).toDouble();
  final top = (y - h - 8 + lift).clamp(0.0, double.infinity).toDouble();
  final rr = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, w, h), const Radius.circular(8));
  c.drawRRect(rr.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.25 * a));
  c.drawRRect(rr, Paint()..color = bg.withValues(alpha: 0.96 * a));
  tp.paint(c, Offset(left + padH, top + padV));
}

String _kcal(double v) => '${v.round()} kcal';
String _g(double v) => '${v.round()} g';

void _label(Canvas c, String s, Offset at, Color color, {double size = 10.5, bool center = true, FontWeight? weight}) {
  final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, center ? at.translate(-tp.width / 2, 0) : at);
}

// =========================================================================
// KALORIE DZIEŃ PO DNIU
// =========================================================================

/// Kalorie z wybranego okresu (7 / 14 / 30 dni) na tle celu. Słupki wyrastają kaskadą,
/// linia celu rysuje się od lewej, dotknięcie lub przeciągnięcie palcem pokazuje dzień z makroskładnikami.
class KcalChart extends StatefulWidget {
  final List<Meal> meals;
  final int goal;
  final String today;
  const KcalChart({super.key, required this.meals, required this.goal, required this.today});

  @override
  State<KcalChart> createState() => _KcalChartState();
}

class _KcalChartState extends State<KcalChart> {
  int span = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = [for (var i = span - 1; i >= 0; i--) shiftDay(widget.today, -i)];
    final totals = [for (final d in days) dayTotal(widget.meals, d)];
    final vals = [for (final t in totals) t.kcal];
    final logged = vals.where((v) => v > 0).toList();
    final avg = logged.isEmpty ? 0.0 : logged.reduce((a, b) => a + b) / logged.length;
    final good = Palette.good(context), bad = Palette.bad(context), amber = Palette.amber(context);
    final muted = cs.onSurfaceVariant;
    final n = days.length;
    final tipBg = cs.inverseSurface, tipFg = cs.onInverseSurface;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(logged.isEmpty ? 'Brak wpisów w tym okresie' : 'Średnio ${avg.round()} kcal w dniu z wpisem',
              style: TextStyle(color: muted, fontSize: 12.5)),
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: const [
            ButtonSegment(value: 7, label: Text('7 d')),
            ButtonSegment(value: 14, label: Text('14 d')),
            ButtonSegment(value: 30, label: Text('30 d')),
          ],
          selected: {span},
          onSelectionChanged: (s) => setState(() => span = s.first),
        ),
      ]),
      const SizedBox(height: 10),
      InteractiveChart(
        height: 170,
        dataKey: Object.hash(span, Object.hashAll(vals), widget.goal),
        count: n,
        indexAt: (p, size) => (p.dx / (size.width / n)).floor().clamp(0, n - 1).toInt(),
        painter: (t, sel, selA) => _KcalPainter(
          days: days,
          totals: totals,
          goal: widget.goal,
          t: t,
          sel: sel,
          selA: selA,
          good: good,
          bad: bad,
          amber: amber,
          muted: muted,
          track: Palette.sunk(context),
          tipBg: tipBg,
          tipFg: tipFg,
        ),
      ),
    ]);
  }
}

class _KcalPainter extends CustomPainter {
  final List<String> days;
  final List<Macros> totals;
  final int goal;
  final double t, selA;
  final int? sel;
  final Color good, bad, amber, muted, track, tipBg, tipFg;
  _KcalPainter({
    required this.days,
    required this.totals,
    required this.goal,
    required this.t,
    required this.sel,
    required this.selA,
    required this.good,
    required this.bad,
    required this.amber,
    required this.muted,
    required this.track,
    required this.tipBg,
    required this.tipFg,
  });

  @override
  void paint(Canvas c, Size size) {
    final n = days.length;
    const labelH = 18.0, topPad = 16.0;
    final chartH = size.height - labelH - topPad;
    final base = topPad + chartH;
    final vals = [for (final m in totals) m.kcal];
    final maxV = [goal * 1.25, ...vals].reduce(max).clamp(1.0, double.infinity);
    final slot = size.width / n;
    final bw = min(30.0, slot * (n > 14 ? 0.7 : 0.62));
    final every = n <= 7 ? 1 : (n <= 14 ? 2 : 5);

    for (var i = 0; i < n; i++) {
      final x = slot * i + (slot - bw) / 2;
      final g = stagger(t, i, n);
      final h = (chartH * vals[i] / maxV) * g;
      final dim = sel != null && sel != i ? 0.55 * selA : 0.0;
      if (h > 0) {
        final over = vals[i] > goal;
        final col = (over ? bad : amber).withValues(alpha: 1 - dim);
        final r = Radius.circular(min(bw / 2, 6));
        c.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(x, base - h, bw, h),
                topLeft: r, topRight: r, bottomLeft: const Radius.circular(2), bottomRight: const Radius.circular(2)),
            Paint()..color = col);
      } else {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, base - 2, bw, 2), const Radius.circular(1)),
            Paint()..color = track);
      }
      if (n <= 7 && vals[i] > 0) {
        _label(c, '${vals[i].round()}', Offset(x + bw / 2, base - h - 14),
            muted.withValues(alpha: (g * (sel == i ? 1 - selA : 1)).clamp(0.0, 1.0)), size: 10);
      }
      if ((n - 1 - i) % every == 0) {
        _label(c, n <= 7 ? shortDay(days[i]) : '${dayOfMonth(days[i])}', Offset(slot * i + slot / 2, base + 4), muted,
            size: 11);
      }
    }

    // linia celu rysuje się od lewej
    if (goal > 0) {
      final y = base - chartH * goal / maxV;
      c.drawLine(Offset(0, y), Offset(size.width * Curves.easeOutCubic.transform(t), y),
          Paint()
            ..color = good.withValues(alpha: 0.85)
            ..strokeWidth = 1.5);
    }

    final s = sel;
    if (s != null && s < n) {
      final m = totals[s];
      final h = chartH * vals[s] / maxV * stagger(t, s, n);
      final text = m.kcal <= 0
          ? '${dayLabel(days[s])} · brak wpisów'
          : '${dayLabel(days[s])} · ${_kcal(m.kcal)}${goal > 0 ? ' (${(m.kcal * 100 / goal).round()}% celu)' : ''}\n'
              'B ${_g(m.p)} · W ${_g(m.c)} · T ${_g(m.f)}';
      paintTip(c, size, text, slot * s + slot / 2, base - h, selA, bg: tipBg, fg: tipFg);
    }
  }

  @override
  bool shouldRepaint(covariant _KcalPainter old) => true;
}

// =========================================================================
// PIERŚCIEŃ MAKROSKŁADNIKÓW
// =========================================================================

/// Udział białka, węglowodanów i tłuszczu w kaloriach dnia. Pierścień nawija się przy pokazaniu;
/// dotknięcie fragmentu wysuwa go i pokazuje gramy oraz procent w środku.
class MacroRing extends StatefulWidget {
  final Macros m;
  final double size;
  const MacroRing({super.key, required this.m, this.size = 96});

  @override
  State<MacroRing> createState() => _MacroRingState();
}

class _MacroRingState extends State<MacroRing> {
  int? sel;

  static const _names = ['Białko', 'Węglowodany', 'Tłuszcz'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = widget.m;
    final kcal = [m.p * 4, m.c * 4, m.f * 9];
    final grams = [m.p, m.c, m.f];
    final total = kcal.reduce((a, b) => a + b);
    final colors = [Palette.good(context), Palette.amber(context), cs.tertiary];
    final shares = [for (final k in kcal) total > 0 ? k / total : 0.0];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        if (total <= 0) return;
        final s = widget.size;
        final v = d.localPosition - Offset(s / 2, s / 2);
        if (v.distance < s * 0.22) {
          setState(() => sel = null);
          return;
        }
        var ang = atan2(v.dy, v.dx) + pi / 2;
        if (ang < 0) ang += 2 * pi;
        final f = ang / (2 * pi);
        var acc = 0.0;
        for (var i = 0; i < 3; i++) {
          acc += shares[i];
          if (f <= acc) {
            HapticFeedback.selectionClick();
            setState(() => sel = sel == i ? null : i);
            return;
          }
        }
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(Object.hash(kcal[0].round(), kcal[1].round(), kcal[2].round())),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: sel == null ? 0 : 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, pop, _) => SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _MacroPainter(shares, colors, t, sel, pop, Palette.sunk(context)),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
                  child: total <= 0
                      ? Text('—', key: const ValueKey('none'), style: TextStyle(color: cs.onSurfaceVariant))
                      : sel == null
                          ? Text('B·W·T',
                              key: const ValueKey('all'),
                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600))
                          : Column(key: ValueKey(sel), mainAxisSize: MainAxisSize.min, children: [
                              Text('${(shares[sel!] * 100).round()}%',
                                  style: TextStyle(
                                      fontSize: widget.size * 0.19, fontWeight: FontWeight.w800, color: colors[sel!])),
                              Text('${_names[sel!]}\n${_g(grams[sel!])}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9.5, height: 1.15, color: cs.onSurfaceVariant)),
                            ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroPainter extends CustomPainter {
  final List<double> shares;
  final List<Color> colors;
  final double t, pop;
  final int? sel;
  final Color track;
  _MacroPainter(this.shares, this.colors, this.t, this.sel, this.pop, this.track);

  @override
  void paint(Canvas c, Size s) {
    final stroke = s.width * 0.13;
    final rect = Rect.fromLTWH(stroke / 2 + 4, stroke / 2 + 4, s.width - stroke - 8, s.height - stroke - 8);
    c.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    final limit = 2 * pi * t;
    var a = 0.0;
    const gap = 0.05;
    for (var i = 0; i < 3; i++) {
      final sweep = 2 * pi * shares[i];
      if (sweep <= 0 || a >= limit) {
        a += sweep;
        continue;
      }
      final isSel = sel == i;
      final mid = -pi / 2 + a + sweep / 2;
      final push = isSel ? 4 * pop : 0.0;
      final r = rect.shift(Offset(cos(mid) * push, sin(mid) * push));
      final dim = sel != null && !isSel;
      c.drawArc(
          r,
          -pi / 2 + a + gap / 2,
          max(0.01, min(sweep, limit - a) - gap),
          false,
          Paint()
            ..color = colors[i].withValues(alpha: dim ? 1 - 0.55 * pop.clamp(0.0, 1.0) : 1)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = stroke + (isSel ? 4 * pop : 0));
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroPainter old) => true;
}

// =========================================================================
// TRAWIENIE — PASEK DNI
// =========================================================================

/// Kafelki dni wg samopoczucia trawiennego. Wskakują po kolei; dotknięcie dnia pokazuje ocenę.
class GutStrip extends StatelessWidget {
  final List<String> days;
  final List<int?> scores;
  final List<int> counts;
  const GutStrip({super.key, required this.days, required this.scores, required this.counts});

  static String word(int? s) => s == null ? 'brak wpisu' : (s >= 4 ? 'dobrze' : (s == 3 ? 'tak sobie' : 'źle'));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = days.length;
    final colors = [for (final s in scores) Palette.comfort(context, s)];
    return LayoutBuilder(builder: (context, box) {
      final cell = box.maxWidth / n;
      return InteractiveChart(
        // miejsce na dymek nad kafelkami
        height: cell + 16 + 40,
        dataKey: Object.hash(Object.hashAll(days), Object.hashAll(scores)),
        count: n,
        duration: const Duration(milliseconds: 700),
        indexAt: (p, size) => (p.dx / (size.width / n)).floor().clamp(0, n - 1).toInt(),
        painter: (t, sel, selA) => _GutPainter(days, scores, counts, colors, t, sel, selA, cs.onSurfaceVariant,
            cs.onSurface, cs.inverseSurface, cs.onInverseSurface),
      );
    });
  }
}

class _GutPainter extends CustomPainter {
  final List<String> days;
  final List<int?> scores;
  final List<int> counts;
  final List<Color> colors;
  final double t, selA;
  final int? sel;
  final Color muted, ring, tipBg, tipFg;
  _GutPainter(this.days, this.scores, this.counts, this.colors, this.t, this.sel, this.selA, this.muted, this.ring,
      this.tipBg, this.tipFg);

  @override
  void paint(Canvas c, Size size) {
    final n = days.length;
    final cell = size.width / n;
    const top = 40.0;
    for (var i = 0; i < n; i++) {
      final g = stagger(t, i, n, spread: 0.5);
      final k = Curves.easeOutBack.transform(g.clamp(0.0, 1.0));
      final side = (cell - 4) * k * (sel == i ? 1 + 0.12 * selA : 1);
      final center = Offset(cell * i + cell / 2, top + cell / 2);
      if (side > 0) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: side, height: side), const Radius.circular(5)),
            Paint()..color = colors[i].withValues(alpha: colors[i].a * g));
        if (sel == i && selA > 0) {
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: side + 3, height: side + 3), const Radius.circular(6)),
              Paint()
                ..color = ring.withValues(alpha: selA)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
        }
      }
      _label(c, '${dayOfMonth(days[i])}', Offset(center.dx, top + cell + 1), muted, size: 9.5);
    }
    final s = sel;
    if (s != null && s < n) {
      final txt = '${dayLabel(days[s])} · ${GutStrip.word(scores[s])}'
          '${counts[s] > 0 ? ' · ${counts[s]} ${counts[s] == 1 ? 'wpis' : (counts[s] < 5 ? 'wpisy' : 'wpisów')}' : ''}';
      paintTip(c, size, txt, cell * s + cell / 2, top - 2, selA, bg: tipBg, fg: tipFg);
    }
  }

  @override
  bool shouldRepaint(covariant _GutPainter old) => true;
}

// =========================================================================
// WIATRY — 14 DNI
// =========================================================================

/// Słupki wiatrów: dzień (Kreska) + noc po nim (Nocny Licznik). Kaskada i dymek z rozbiciem.
class GasBars extends StatelessWidget {
  final List<String> days;
  final List<int?> day;
  final List<int?> night;
  final Color dayColor, nightColor;
  const GasBars(
      {super.key,
      required this.days,
      required this.day,
      required this.night,
      required this.dayColor,
      required this.nightColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = days.length;
    return InteractiveChart(
      height: 140,
      dataKey: Object.hash(Object.hashAll(day), Object.hashAll(night)),
      count: n,
      indexAt: (p, size) => (p.dx / (size.width / n)).floor().clamp(0, n - 1).toInt(),
      painter: (t, sel, selA) => _GasPainter(days, day, night, dayColor, nightColor, t, sel, selA, cs.onSurfaceVariant,
          cs.inverseSurface, cs.onInverseSurface),
    );
  }
}

class _GasPainter extends CustomPainter {
  final List<String> days;
  final List<int?> day, night;
  final Color dayColor, nightColor, muted, tipBg, tipFg;
  final double t, selA;
  final int? sel;
  _GasPainter(this.days, this.day, this.night, this.dayColor, this.nightColor, this.t, this.sel, this.selA, this.muted,
      this.tipBg, this.tipFg);

  @override
  void paint(Canvas c, Size size) {
    final n = days.length;
    const labelH = 16.0, topPad = 34.0;
    final chartH = size.height - labelH - topPad;
    final base = topPad + chartH;
    final mx = [1, for (var i = 0; i < n; i++) (day[i] ?? 0) + (night[i] ?? 0)].reduce(max).toDouble();
    final slot = size.width / n;
    final bw = slot - 4;
    for (var i = 0; i < n; i++) {
      final g = stagger(t, i, n);
      final dim = sel != null && sel != i ? 0.55 * selA : 0.0;
      final x = slot * i + 2;
      final hd = chartH * (day[i] ?? 0) / mx * g;
      final hn = chartH * (night[i] ?? 0) / mx * g;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, base - hd - 1, bw, hd + 1), const Radius.circular(2)),
          Paint()..color = dayColor.withValues(alpha: 1 - dim));
      if (hn > 0) {
        c.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(x, base - hd - hn - 1, bw, hn),
                topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
            Paint()..color = nightColor.withValues(alpha: 1 - dim));
      }
      final total = (day[i] ?? 0) + (night[i] ?? 0);
      final none = day[i] == null && night[i] == null;
      _label(c, none ? '–' : '$total', Offset(x + bw / 2, base - hd - hn - 14),
          muted.withValues(alpha: (g * (sel == i ? 1 - selA : 1)).clamp(0.0, 1.0)), size: 9.5);
      _label(c, '${dayOfMonth(days[i])}', Offset(x + bw / 2, base + 2), muted, size: 9.5);
    }
    final s = sel;
    if (s != null && s < n) {
      final total = (day[s] ?? 0) + (night[s] ?? 0);
      final parts = [
        if (day[s] != null) 'dzień ${day[s]}',
        if (night[s] != null) 'noc ${night[s]}',
      ];
      final txt = parts.isEmpty ? '${dayLabel(days[s])} · brak danych' : '${dayLabel(days[s])} · ${parts.join(' + ')}';
      final h = chartH * total / mx * stagger(t, s, n);
      paintTip(c, size, txt, slot * s + slot / 2, base - h - 2, selA, bg: tipBg, fg: tipFg);
    }
  }

  @override
  bool shouldRepaint(covariant _GasPainter old) => true;
}

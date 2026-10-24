import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../food_db.dart';
import '../models.dart';
import 'format.dart';

/// Skanuje kod kreskowy, pobiera produkt z Open Food Facts i pyta o ilość. Zwraca składnik albo null.
Future<FoodItem?> scanFood(BuildContext context) async {
  final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScannerScreen()));
  if (code == null || !context.mounted) return null;
  Product? p;
  String? err;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      FoodDb.byBarcode(code).then((v) => p = v).catchError((Object e) {
        err = e is FoodDbError ? e.message : 'Nie udało się pobrać produktu.';
        return null;
      }).whenComplete(() {
        if (c.mounted) Navigator.pop(c);
      });
      return const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Szukam produktu…'))]));
    },
  );
  if (!context.mounted) return null;
  if (err != null) {
    toast(context, err!);
    return null;
  }
  if (p == null) {
    toast(context, 'Nie ma produktu $code w bazie Open Food Facts. Dodaj składnik ręcznie.');
    return null;
  }
  if (p!.kcal100 <= 0) {
    toast(context, 'Produkt „${p!.label}” nie ma w bazie wartości odżywczych. Uzupełnij je ręcznie.');
  }
  return showDialog<FoodItem>(context: context, builder: (_) => _AmountDialog(product: p!));
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final controller = MobileScannerController(formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE]);
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeskanuj kod kreskowy'),
        actions: [IconButton(tooltip: 'Latarka', icon: const Icon(Icons.flashlight_on_outlined), onPressed: () => controller.toggleTorch())],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            if (done) return;
            final v = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((s) => s.isNotEmpty);
            if (v.isEmpty) return;
            done = true;
            Navigator.pop(context, v.first);
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nie można uruchomić aparatu. Sprawdź uprawnienie do aparatu w ustawieniach telefonu.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Text('Nakieruj aparat na kod kreskowy na opakowaniu', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 6)])),
        ),
      ]),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  final Product product;
  const _AmountDialog({required this.product});
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final grams = TextEditingController(text: numInput(widget.product.serving ?? 100));

  @override
  void dispose() {
    grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final g = parseNum(grams.text) ?? 0;
    final f = g / 100;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(p.label),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Na 100 g: ${p.kcal100.round()} kcal · B ${p.protein100.toStringAsFixed(1)} · W ${p.carbs100.toStringAsFixed(1)} · T ${p.fat100.toStringAsFixed(1)}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 14),
        TextField(
          controller: grams,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Ile zjadłeś (g lub ml)', helperText: p.serving != null ? 'Porcja na opakowaniu: ${p.serving!.round()} g' : null),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('${(p.kcal100 * f).round()} kcal · B ${(p.protein100 * f).round()} · W ${(p.carbs100 * f).round()} · T ${(p.fat100 * f).round()}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tabular)),
        const SizedBox(height: 8),
        Text('Dane: Open Food Facts', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
        FilledButton(
          onPressed: g <= 0
              ? null
              : () => Navigator.pop(
                    context,
                    FoodItem(name: p.label, grams: g, kcal: p.kcal100 * f, protein: p.protein100 * f, carbs: p.carbs100 * f, fat: p.fat100 * f),
                  ),
          child: const Text('Dodaj'),
        ),
      ],
    );
  }
}

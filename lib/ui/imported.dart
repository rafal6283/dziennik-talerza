import 'package:flutter/material.dart';

/// Delikatne wyróżnienie danych z współpracujących aplikacji (Kreska, Rytm Snu):
/// mała etykieta w obwódce z ikoną łącza, np. „z Kreski · z Rytmu Snu”.
class ImportedTag extends StatelessWidget {
  final String text;
  const ImportedTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.link, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Opis źródeł danych FF dla etykiety.
String importedFromGas({required bool kreska, required bool night}) =>
    [if (kreska) 'z Kreski', if (night) 'z Rytmu Snu'].join(' · ');

import 'package:flutter/material.dart';

import '../local_ai.dart';
import 'format.dart';

/// Pobieranie i usuwanie darmowego modelu działającego na telefonie.
class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});
  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  bool? installed;
  int? progress; // null = nie pobiera
  String? error;
  String? testResult;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    LocalAi.installed().then((v) {
      if (mounted) setState(() => installed = v);
    });
  }

  Future<void> _download() async {
    setState(() {
      progress = 0;
      error = null;
    });
    try {
      await LocalAi.download((p) {
        if (mounted) setState(() => progress = p);
      });
      if (!mounted) return;
      setState(() {
        installed = true;
        progress = null;
      });
      toast(context, 'Model gotowy. Rozpoznawanie działa bez internetu.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        progress = null;
        error = LocalAi.isCancel(e) ? null : 'Pobieranie się nie udało. Sprawdź internet i wolne miejsce (potrzeba ok. 3 GB), potem spróbuj ponownie.';
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Usunąć model?', 'Zwolnisz ok. ${LocalAi.sizeLabel}. Rozpoznawanie na telefonie przestanie działać, dopóki nie pobierzesz modelu ponownie.')) return;
    await LocalAi.delete();
    if (mounted) setState(() => installed = false);
  }

  Future<void> _test() async {
    setState(() {
      testing = true;
      testResult = null;
    });
    final sw = Stopwatch()..start();
    try {
      final t = await LocalAi.ask('Podaj jednym zdaniem po polsku, ile mniej więcej kalorii ma jedno średnie jabłko.', maxOutputTokens: 80);
      testResult = '$t\n\n(odpowiedź w ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s, pierwsze uruchomienie jest wolniejsze)';
    } catch (e) {
      testResult = 'Model nie zadziałał na tym telefonie: $e';
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = progress;
    return PopScope(
      canPop: p == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Model na telefonie')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Gemma 4 E2B', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Otwarty model Google. Rozpoznaje posiłki ze zdjęć i opisów, uzupełnia formularze z dyktowania i analizuje wzorce – w całości na telefonie, '
              'bez internetu, bez konta i bez opłat. Zdjęcia nie opuszczają telefonu.'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row(Icons.download_outlined, 'Jednorazowe pobranie ${LocalAi.sizeLabel} – najlepiej przez Wi-Fi'),
              _row(Icons.memory, 'Najlepiej działa na telefonach z 8 GB RAM; przy 6 GB może być wolny'),
              _row(Icons.timer_outlined, 'Rozpoznanie zdjęcia trwa zwykle 10–40 s'),
              _row(Icons.straighten, 'Gramatury szacuje mniej dokładnie niż Claude – sprawdzaj i poprawiaj'),
            ]),
          ),
          const SizedBox(height: 20),
          if (installed == null)
            const Center(child: CircularProgressIndicator())
          else if (p != null) ...[
            Text('Pobieranie: $p%', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tabular)),
            const SizedBox(height: 8),
            Meter(p / 100, cs.primary, height: 10),
            const SizedBox(height: 8),
            Text('Nie zamykaj aplikacji do końca pobierania.', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: LocalAi.cancelDownload, child: const Text('Anuluj pobieranie')),
          ] else if (installed!) ...[
            Row(children: [Icon(Icons.check_circle, color: Palette.good(context)), const SizedBox(width: 8), const Text('Model pobrany i gotowy', style: TextStyle(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: testing ? null : _test,
              icon: testing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
              label: Text(testing ? 'Model myśli…' : 'Sprawdź, czy działa'),
            ),
            if (testResult != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(testResult!),
              ),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: _delete, style: TextButton.styleFrom(foregroundColor: cs.error), icon: const Icon(Icons.delete_outline), label: const Text('Usuń model z telefonu')),
          ] else
            FilledButton.icon(
              onPressed: _download,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.download),
              label: Text('Pobierz model (${LocalAi.sizeLabel})'),
            ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 24),
          Text('Model pobierany jest z Hugging Face (litert-community/gemma-4-E2B-it-litert-lm).', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _row(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, size: 20), const SizedBox(width: 10), Expanded(child: Text(t))]),
      );
}

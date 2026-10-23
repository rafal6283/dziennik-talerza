// Dyktowanie głosem (rozpoznawanie mowy systemu: Google na Androidzie, Apple na iPhonie).

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'format.dart';

class Voice {
  static final SpeechToText stt = SpeechToText();
  static bool? _ready;
  static String? _locale;
  static void Function(String)? _onStatus;
  static void Function(SpeechRecognitionError)? _onError;

  static Future<bool> init() async {
    if (_ready == true) return true;
    try {
      _ready = await stt.initialize(
        onStatus: (s) => _onStatus?.call(s),
        onError: (e) => _onError?.call(e),
      );
    } catch (_) {
      _ready = false;
    }
    if (_ready == true && _locale == null) {
      try {
        final ls = await stt.locales();
        final pl = ls.where((l) => l.localeId.toLowerCase().startsWith('pl'));
        _locale = pl.isNotEmpty ? pl.first.localeId : 'pl_PL';
      } catch (_) {
        _locale = 'pl_PL';
      }
    }
    return _ready == true;
  }
}

/// Otwiera arkusz dyktowania. Zwraca rozpoznany tekst albo null.
Future<String?> dictate(BuildContext context, {String title = 'Mów', String? hint}) async {
  if (!await Voice.init()) {
    if (context.mounted) {
      toast(context, 'Rozpoznawanie mowy jest niedostępne. Sprawdź uprawnienie do mikrofonu w ustawieniach telefonu.');
    }
    return null;
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DictateSheet(title: title, hint: hint),
  );
}

class _DictateSheet extends StatefulWidget {
  final String title;
  final String? hint;
  const _DictateSheet({required this.title, this.hint});
  @override
  State<_DictateSheet> createState() => _DictateSheetState();
}

class _DictateSheetState extends State<_DictateSheet> with SingleTickerProviderStateMixin {
  String done = ''; // zakończone fragmenty
  String partial = '';
  bool listening = false;
  String? error;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  String get text => [done, partial].where((s) => s.trim().isNotEmpty).join(' ').trim();

  @override
  void initState() {
    super.initState();
    Voice._onStatus = (s) {
      if (!mounted) return;
      if (s == 'done' || s == 'notListening') setState(() => listening = false);
    };
    Voice._onError = (e) {
      if (!mounted) return;
      setState(() {
        listening = false;
        error = switch (e.errorMsg) {
          'error_no_match' || 'error_speech_timeout' => 'Nic nie usłyszałem. Stuknij mikrofon i spróbuj jeszcze raz.',
          'error_permission' || 'error_insufficient_permissions' => 'Brak uprawnienia do mikrofonu. Włącz je w ustawieniach telefonu.',
          'error_network' || 'error_network_timeout' => 'Rozpoznawanie mowy potrzebuje internetu albo pobranego języka polskiego.',
          _ => 'Błąd rozpoznawania mowy (${e.errorMsg}).',
        };
      });
    };
    _start();
  }

  Future<void> _start() async {
    if (partial.trim().isNotEmpty) done = text;
    partial = '';
    setState(() {
      error = null;
      listening = true;
    });
    try {
      await Voice.stt.listen(
        onResult: _onResult,
        localeId: Voice._locale,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, cancelOnError: true),
      );
    } catch (e) {
      setState(() {
        listening = false;
        error = 'Nie udało się włączyć mikrofonu.';
      });
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() {
      partial = r.recognizedWords;
      if (r.finalResult) {
        done = text;
        partial = '';
      }
    });
  }

  Future<void> _stop() async {
    await Voice.stt.stop();
    if (mounted) setState(() => listening = false);
  }

  @override
  void dispose() {
    pulse.dispose();
    Voice.stt.cancel();
    Voice._onStatus = null;
    Voice._onError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        if (widget.hint != null) ...[
          const SizedBox(height: 4),
          Text(widget.hint!, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: done),
            if (partial.isNotEmpty) TextSpan(text: '${done.isEmpty ? '' : ' '}$partial', style: TextStyle(color: cs.onSurfaceVariant)),
            if (text.isEmpty)
              TextSpan(text: listening ? 'Słucham…' : 'Stuknij mikrofon, żeby mówić', style: TextStyle(color: cs.onSurfaceVariant)),
          ]), style: const TextStyle(fontSize: 17, height: 1.35)),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => GestureDetector(
              onTap: listening ? _stop : _start,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? cs.error : cs.primary,
                  boxShadow: listening ? [BoxShadow(color: cs.error.withValues(alpha: 0.35), blurRadius: 6 + 12 * pulse.value, spreadRadius: 2 * pulse.value)] : null,
                ),
                child: Icon(listening ? Icons.stop_rounded : Icons.mic, color: listening ? cs.onError : cs.onPrimary, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(listening ? 'Mów. Stuknij, żeby zakończyć.' : 'Stuknij, żeby mówić dalej.', style: TextStyle(color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          const SizedBox(width: 8),
          FilledButton(onPressed: text.isEmpty ? null : () => Navigator.pop(context, text), child: const Text('Gotowe')),
        ]),
      ]),
    );
  }
}

/// Przycisk mikrofonu do pola tekstowego – dopisuje podyktowany tekst.
class MicButton extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final VoidCallback? onChanged;
  const MicButton({super.key, required this.controller, this.title = 'Dyktuj', this.onChanged});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Dyktuj',
        icon: const Icon(Icons.mic_none),
        onPressed: () async {
          final t = await dictate(context, title: title);
          if (t == null || t.isEmpty) return;
          final cur = controller.text.trim();
          controller.text = cur.isEmpty ? t : '$cur $t';
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
          onChanged?.call();
        },
      );
}

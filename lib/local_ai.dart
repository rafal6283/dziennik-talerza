// Darmowe rozpoznawanie na telefonie: Gemma 4 E2B (Google, otwarta licencja) uruchamiana lokalnie
// przez flutter_edge_ai + silnik LiteRT-LM. Bez internetu (poza jednorazowym pobraniem), bez klucza, bez limitów.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAi {
  static const modelUrl = 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
  static const modelFile = 'gemma-4-E2B-it.litertlm';
  static const sizeLabel = '2,6 GB';
  static const _kReady = 'local_model_ready';

  static bool _initDone = false;
  static InferenceModel? _model;
  static Future<void>? _queue;
  static CancelToken? _cancel;
  static Timer? _idle;

  static Future<void> _init() async {
    if (_initDone) return;
    await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
    _initDone = true;
  }

  /// Szybkie sprawdzenie bez ładowania silnika (zapisane po udanym pobraniu).
  static Future<bool> ready() async => (await SharedPreferences.getInstance()).getBool(_kReady) ?? false;

  /// Dokładne sprawdzenie w menedżerze modeli.
  static Future<bool> installed() async {
    try {
      await _init();
      final ok = await FlutterEdgeAi.isModelInstalled(modelFile);
      await (await SharedPreferences.getInstance()).setBool(_kReady, ok);
      return ok;
    } catch (_) {
      return false;
    }
  }

  static InferenceInstallationBuilder _builder() =>
      FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm).fromNetwork(modelUrl);

  static Future<void> download(void Function(int percent) onProgress) async {
    await _init();
    final token = CancelToken();
    _cancel = token;
    try {
      await _builder().withProgress(onProgress).withCancelToken(token).install();
      await (await SharedPreferences.getInstance()).setBool(_kReady, true);
    } finally {
      _cancel = null;
    }
  }

  static void cancelDownload() => _cancel?.cancel('Anulowano');
  static bool isCancel(Object e) => CancelToken.isCancel(e);

  static Future<void> delete() async {
    await _closeModel();
    await (await SharedPreferences.getInstance()).setBool(_kReady, false);
    await _init();
    try {
      await FlutterEdgeAi.uninstallModel(modelFile);
    } catch (_) {}
  }

  static Future<void> _closeModel() async {
    _idle?.cancel();
    final m = _model;
    _model = null;
    if (m != null) {
      try {
        await m.close();
      } catch (_) {}
    }
  }

  static Future<InferenceModel> _load() async {
    if (_model != null) return _model!;
    await _init();
    // ustawia model jako aktywny; gdy plik już jest, nic nie pobiera
    await _builder().install();
    try {
      _model = await FlutterEdgeAi.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.gpu, supportImage: true);
    } catch (_) {
      // część telefonów nie ma sterownika GPU obsługiwanego przez LiteRT – próbujemy na procesorze
      _model = await FlutterEdgeAi.getActiveModel(maxTokens: 4096, preferredBackend: PreferredBackend.cpu, supportImage: true);
    }
    return _model!;
  }

  /// Jedno zapytanie (tekst albo tekst + zdjęcie). Zapytania idą po kolei.
  static Future<String> ask(String prompt, {Uint8List? image, int maxOutputTokens = 1024}) async {
    final prev = _queue;
    final done = Completer<void>();
    _queue = done.future;
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }
    _idle?.cancel();
    try {
      final m = await _load();
      final chat = await m.createChat(supportImage: image != null, maxOutputTokens: maxOutputTokens, temperature: 0.2);
      try {
        await chat.addQueryChunk(image != null
            ? Message.withImage(text: prompt, imageBytes: image, isUser: true)
            : Message.text(text: prompt, isUser: true));
        final out = StringBuffer();
        await for (final r in chat.generateChatResponseAsync()) {
          if (r is TextResponse) out.write(r.token);
        }
        return out.toString().trim();
      } finally {
        await chat.close();
      }
    } finally {
      done.complete();
      // model zajmuje kilka GB pamięci – zwalniamy go po 3 minutach bezczynności
      _idle = Timer(const Duration(minutes: 3), _closeModel);
    }
  }
}

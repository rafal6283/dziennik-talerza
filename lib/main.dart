import 'package:flutter/material.dart';
import 'package:koofr_backup_ui/koofr_backup_ui.dart' show KoofrBackground, KoofrBackup;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'koofr_backup.dart';
import 'food_pack.dart';
import 'health.dart';
import 'security/lock.dart';
import 'store.dart';
import 'ui/format.dart';
import 'ui/home.dart';
import 'ui/lock_screen.dart';

final AppState app = AppState();

/// >0, gdy aplikacja sama otworzyła aparat, galerię albo okno pliku.
int externalActivity = 0;

Future<T> withExternal<T>(Future<T> Function() f) async {
  externalActivity++;
  try {
    return await f();
  } finally {
    // powrót do aplikacji (resumed) przychodzi tuż przed zakończeniem – licznik zdejmujemy z opóźnieniem
    Future.delayed(const Duration(seconds: 2), () => externalActivity--);
  }
}

/// Kopia na Koofr w tle (Android) — także przy zamkniętej aplikacji.
@pragma('vm:entry-point')
void koofrCallback() => KoofrBackground.dispatch(() async {
      await app.load();
      return DziennikBackup();
    });

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FoodPack.load(); // paczka produktów wczytuje się w tle
  // posiłki wybranej osoby → Health Connect (Samsung Health, Google Fit)
  HealthSync.init();
  app.onMealSaved = HealthSync.mealSaved;
  app.onMealDeleted = HealthSync.mealDeleted;
  runApp(const DziennikApp());
}

class DziennikApp extends StatelessWidget {
  const DziennikApp({super.key});

  ThemeData _theme(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: Palette.seed, brightness: b);
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      appBarTheme: AppBarTheme(backgroundColor: cs.surface, scrolledUnderElevation: 1, centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dziennik talerza',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      home: const HomeScreen(),
    );
  }
}

/// Opcjonalne logowanie (domyślnie wyłączone) – zasłania też otwarte formularze.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  LockConfig? config;
  bool locked = true;
  bool covered = false;
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([Lock.load(), app.load()]);
    // kopia na Koofr w tle (po wczytaniu danych)
    KoofrBackup.setup(DziennikBackup()).then((_) => KoofrBackground.start(koofrCallback)).ignore();
    final c = results.first as LockConfig;
    if (!mounted) return;
    setState(() {
      config = c;
      locked = c.method != LockMethod.none;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final on = (config?.method ?? LockMethod.none) != LockMethod.none;
    if (on && (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) && !covered && !locked) {
      setState(() => covered = true);
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) pausedAt ??= DateTime.now();
    if (state == AppLifecycleState.resumed) {
      if (covered) setState(() => covered = false);
      if (pausedAt == null) return;
      final away = DateTime.now().difference(pausedAt!);
      pausedAt = null;
      Lock.load().then((c) {
        if (!mounted) return;
        // aparat, galeria i wybór pliku to „wyjście” z aplikacji – wtedy nie blokujemy
        final limit = c.timeoutSec < 15 ? 15 : c.timeoutSec;
        final external = externalActivity > 0;
        setState(() {
          config = c;
          if (c.method != LockMethod.none && !external && away.inSeconds >= limit) locked = true;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = config;
    return Stack(children: [
      Offstage(offstage: c == null || locked, child: widget.child),
      if (c == null) const Positioned.fill(child: Scaffold(body: SizedBox())),
      if (c != null && locked)
        Positioned.fill(
          child: HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => LockScreen(config: c, onUnlocked: () => setState(() => locked = false)),
              ),
            ),
          ),
        ),
      if (covered && !locked)
        Positioned.fill(
          child: ColoredBox(
            color: Palette.board,
            child: const Center(child: Icon(Icons.lock_outline, color: Palette.boardDim, size: 48)),
          ),
        ),
    ]);
  }
}

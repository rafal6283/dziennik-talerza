package pl.dziennik.dziennik_talerza

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // Rejestracja przed onCreate — wymóg registerForActivityResult.
    private val health = HealthBridge(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.dziennik/health")
            .setMethodCallHandler { call, result -> health.handle(call, result) }
    }
}

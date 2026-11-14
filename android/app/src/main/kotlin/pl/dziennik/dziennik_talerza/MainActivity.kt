package pl.dziennik.dziennik_talerza

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    // Rejestracja przed onCreate — wymóg registerForActivityResult.
    private val health = HealthBridge(this)
    private var widgetChannel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.dziennik/health")
            .setMethodCallHandler { call, result -> health.handle(call, result) }
        pendingAction = intent?.getStringExtra(DziennikWidget.EXTRA)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.dziennik/widget").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                        DziennikWidget.save(applicationContext, data)
                        result.success(true)
                    }
                    // akcja z widżetu, którą uruchomiono aplikację (jednorazowo)
                    "takeAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val a = intent.getStringExtra(DziennikWidget.EXTRA) ?: return
        val ch = widgetChannel
        if (ch == null) pendingAction = a else ch.invokeMethod("action", a)
    }
}

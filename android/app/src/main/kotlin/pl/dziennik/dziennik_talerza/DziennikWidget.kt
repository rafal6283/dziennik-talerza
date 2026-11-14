package pl.dziennik.dziennik_talerza

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widżet na ekran główny: dzisiejsze kalorie i woda + szybkie akcje (posiłek, woda, trawienie).
 * Dane podaje aplikacja (kanał pl.dziennik/widget → update); akcje otwierają aplikację z polem "akcja".
 */
class DziennikWidget : AppWidgetProvider() {
    companion object {
        const val PREFS = "dziennik_widget"
        const val EXTRA = "dziennik_action"

        fun save(ctx: Context, data: Map<String, Any?>) {
            val e = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            for ((k, v) in data) e.putString(k, v?.toString() ?: "")
            e.apply()
            refresh(ctx)
        }

        fun refresh(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, DziennikWidget::class.java))
            for (id in ids) mgr.updateAppWidget(id, views(ctx))
        }

        private fun launch(ctx: Context, action: String, code: Int): PendingIntent {
            val i = Intent(ctx, MainActivity::class.java)
                .setAction("pl.dziennik.ACTION_$action")
                .putExtra(EXTRA, action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(ctx, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun views(ctx: Context): RemoteViews {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val v = RemoteViews(ctx.packageName, R.layout.widget_dziennik)
            v.setTextViewText(R.id.w_person, p.getString("person", "") ?: "")
            v.setTextViewText(R.id.w_kcal, p.getString("kcal", "–") ?: "–")
            v.setTextViewText(R.id.w_goal, p.getString("goalText", "Otwórz aplikację") ?: "")
            v.setTextViewText(R.id.w_water, p.getString("waterText", "") ?: "")
            val pct = (p.getString("pct", "0") ?: "0").toIntOrNull() ?: 0
            v.setProgressBar(R.id.w_progress, 100, pct.coerceIn(0, 100), false)
            v.setOnClickPendingIntent(R.id.w_root, launch(ctx, "open", 10))
            v.setOnClickPendingIntent(R.id.w_meal, launch(ctx, "meal", 11))
            v.setOnClickPendingIntent(R.id.w_add_water, launch(ctx, "water", 12))
            v.setOnClickPendingIntent(R.id.w_gut, launch(ctx, "gut", 13))
            return v
        }
    }

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(ctx))
    }
}

package pl.dziennik.dziennik_talerza

import android.app.Activity
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView

/** Wymagany przez Health Connect ekran z wyjaśnieniem, po co aplikacji dostęp. */
class PrivacyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (20 * resources.displayMetrics.density).toInt()
        val text = TextView(this).apply {
            setPadding(pad, pad, pad, pad)
            textSize = 16f
            text = "Dziennik talerza zapisuje w Health Connect Twoje posiłki: godzinę, nazwę, kalorie, " +
                "białko, węglowodany i tłuszcz. Dzięki temu zobaczysz je np. w Samsung Health albo Google Fit.\n\n" +
                "Aplikacja niczego z Health Connect nie odczytuje. Zapis możesz wyłączyć w ustawieniach aplikacji, " +
                "a zgodę cofnąć w Health Connect."
        }
        setContentView(ScrollView(this).apply { addView(text) })
    }
}

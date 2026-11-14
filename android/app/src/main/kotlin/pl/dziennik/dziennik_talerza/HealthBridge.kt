package pl.dziennik.dziennik_talerza

import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.records.MealType
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.Period
import java.time.ZoneId

/**
 * Posiłki → Health Connect (rekordy odżywiania: kcal, białko, węglowodany, tłuszcz).
 * Stąd biorą je Samsung Health, Google Fit i inne aplikacje.
 * clientRecordId = id posiłku, więc ponowny zapis aktualizuje rekord zamiast go dublować.
 */
class HealthBridge(private val activity: ComponentActivity) {
    companion object {
        private const val TAG = "DziennikHC"
        private const val PROVIDER = "com.google.android.apps.healthdata"
        val PERMS = setOf(HealthPermission.getWritePermission(NutritionRecord::class))
        val ACTIVITY = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        )
        fun recordId(mealId: String) = "dziennik-meal-$mealId"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pending: MethodChannel.Result? = null
    private var pendingPerms: Set<String> = PERMS

    private val launcher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            val r = pending ?: return@registerForActivityResult
            pending = null
            r.success(granted.containsAll(pendingPerms))
        }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "hasPermission" -> scope.launch { result.success(granted()) }
            "requestPermission" -> request(result, PERMS)
            "hasActivity" -> scope.launch { result.success(granted(ACTIVITY)) }
            "requestActivity" -> request(result, ACTIVITY)
            "activity" -> {
                val days = call.argument<Int>("days") ?: 14
                scope.launch { result.success(activity(days)) }
            }
            "writeMeals" -> {
                val meals = call.argument<List<Map<String, Any?>>>("meals") ?: emptyList()
                scope.launch { result.success(write(meals)) }
            }
            "deleteMeals" -> {
                val ids = call.argument<List<String>>("ids") ?: emptyList()
                scope.launch { result.success(delete(ids)) }
            }
            else -> result.notImplemented()
        }
    }

    private fun status(): String = when (HealthConnectClient.getSdkStatus(activity, PROVIDER)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update"
        else -> "unavailable"
    }

    private suspend fun granted(perms: Set<String> = PERMS): Boolean = try {
        status() == "available" &&
            HealthConnectClient.getOrCreate(activity).permissionController.getGrantedPermissions().containsAll(perms)
    } catch (e: Exception) {
        Log.w(TAG, "Uprawnienia", e)
        false
    }

    private fun request(result: MethodChannel.Result, perms: Set<String>) {
        when (status()) {
            "update" -> {
                try {
                    val uri = Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding")
                    activity.startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage("com.android.vending"))
                } catch (e: Exception) {
                    Log.w(TAG, "Sklep Play", e)
                }
                result.success(false)
                return
            }
            "unavailable" -> {
                result.success(false)
                return
            }
        }
        scope.launch {
            if (granted(perms)) {
                result.success(true)
                return@launch
            }
            pending?.success(false)
            pending = result
            pendingPerms = perms
            launcher.launch(perms)
        }
    }

    private fun mealType(t: String?): Int = when (t) {
        "Śniadanie", "Drugie śniadanie" -> MealType.MEAL_TYPE_BREAKFAST
        "Obiad" -> MealType.MEAL_TYPE_LUNCH
        "Kolacja" -> MealType.MEAL_TYPE_DINNER
        "Podwieczorek", "Przekąska" -> MealType.MEAL_TYPE_SNACK
        else -> MealType.MEAL_TYPE_UNKNOWN
    }

    private fun num(v: Any?): Double = (v as? Number)?.toDouble() ?: 0.0

    /** Zapisuje posiłki; zwraca liczbę zapisanych albo -1. */
    private suspend fun write(meals: List<Map<String, Any?>>): Int {
        if (!granted()) return -1
        val version = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val records = meals.mapNotNull { m ->
            val id = m["id"] as? String ?: return@mapNotNull null
            val ts = (m["ts"] as? Number)?.toLong() ?: return@mapNotNull null
            val kcal = num(m["kcal"])
            if (kcal <= 0.0) return@mapNotNull null
            val start = Instant.ofEpochMilli(ts)
            val end = start.plusSeconds(60)
            NutritionRecord(
                startTime = start,
                startZoneOffset = zone.rules.getOffset(start),
                endTime = end,
                endZoneOffset = zone.rules.getOffset(end),
                name = (m["name"] as? String)?.takeIf { it.isNotBlank() },
                mealType = mealType(m["type"] as? String),
                energy = Energy.kilocalories(kcal),
                protein = Mass.grams(num(m["p"])),
                totalCarbohydrate = Mass.grams(num(m["c"])),
                totalFat = Mass.grams(num(m["f"])),
                metadata = Metadata(clientRecordId = recordId(id), clientRecordVersion = version),
            )
        }
        if (records.isEmpty()) return 0
        return try {
            val client = HealthConnectClient.getOrCreate(activity)
            records.chunked(100).forEach { client.insertRecords(it) }
            records.size
        } catch (e: Exception) {
            Log.w(TAG, "Zapis posiłków", e)
            -1
        }
    }

    /** Kroki i aktywne kalorie z ostatnich [days] dni: data (yyyy-MM-dd) → {steps, kcal}. Null bez zgody. */
    private suspend fun activity(days: Int): Map<String, Map<String, Any>>? {
        if (!granted(ACTIVITY)) return null
        return try {
            val end = LocalDate.now().plusDays(1).atStartOfDay()
            val start = LocalDate.now().minusDays((days - 1).toLong()).atStartOfDay()
            val groups = HealthConnectClient.getOrCreate(activity).aggregateGroupByPeriod(
                AggregateGroupByPeriodRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL, ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    timeRangeSlicer = Period.ofDays(1),
                )
            )
            val out = HashMap<String, Map<String, Any>>()
            for (g in groups) {
                val steps = g.result[StepsRecord.COUNT_TOTAL] ?: 0L
                val kcal = g.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0
                if (steps == 0L && kcal == 0.0) continue
                out[g.startTime.toLocalDate().toString()] = mapOf("steps" to steps, "kcal" to kcal)
            }
            out
        } catch (e: Exception) {
            Log.w(TAG, "Aktywność", e)
            null
        }
    }

    /** Usuwa posiłki (po id z dziennika). */
    private suspend fun delete(ids: List<String>): Boolean {
        if (ids.isEmpty() || !granted()) return false
        return try {
            HealthConnectClient.getOrCreate(activity).deleteRecords(
                NutritionRecord::class,
                recordIdsList = emptyList(),
                clientRecordIdsList = ids.map { recordId(it) },
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "Usuwanie posiłków", e)
            false
        }
    }
}

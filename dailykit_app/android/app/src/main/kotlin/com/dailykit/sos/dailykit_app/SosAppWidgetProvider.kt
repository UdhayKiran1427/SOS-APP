package com.dailykit.sos.dailykit_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews

class SosAppWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_TAP = "com.dailykit.sos.ACTION_WIDGET_TAP"
        private const val PREFS_NAME = "DailyKitWidgetPrefs"
        private const val KEY_LAST_TAP = "last_tap_timestamp"
        private const val KEY_TAP_COUNT = "tap_count"
        private const val SEQUENCE_TIMEOUT_MS = 600L

        private val handler = Handler(Looper.getMainLooper())
        private var pendingSingleTapRunnable: Runnable? = null
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget_layout)

            // Intent when clicking the SOS widget button
            val tapIntent = Intent(context, SosAppWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_TAP
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_sos_button, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_WIDGET_TAP) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val lastTap = prefs.getLong(KEY_LAST_TAP, 0L)
            var count = prefs.getInt(KEY_TAP_COUNT, 0)

            if (now - lastTap <= SEQUENCE_TIMEOUT_MS) {
                count++
            } else {
                count = 1
            }

            prefs.edit()
                .putLong(KEY_LAST_TAP, now)
                .putInt(KEY_TAP_COUNT, count)
                .apply()

            if (count >= 3) {
                // Triple tap detected!
                pendingSingleTapRunnable?.let { handler.removeCallbacks(it) }
                pendingSingleTapRunnable = null
                prefs.edit().putInt(KEY_TAP_COUNT, 0).apply()

                launchApp(context, "TRIGGER_SOS")
            } else if (count == 1) {
                // Single tap detected: wait 600ms to verify if another tap arrives
                pendingSingleTapRunnable?.let { handler.removeCallbacks(it) }
                val runnable = Runnable {
                    val currentCount = prefs.getInt(KEY_TAP_COUNT, 0)
                    if (currentCount == 1) {
                        prefs.edit().putInt(KEY_TAP_COUNT, 0).apply()
                        launchApp(context, "OPEN_CONTACTS")
                    }
                }
                pendingSingleTapRunnable = runnable
                handler.postDelayed(runnable, SEQUENCE_TIMEOUT_MS)
            }
        }
    }

    private fun launchApp(context: Context, routeAction: String) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("route_action", routeAction)
        }
        context.startActivity(launchIntent)
    }
}


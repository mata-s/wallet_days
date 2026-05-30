package com.matayoshi.walletdays

import com.matayoshi.walletdays.R
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.view.View
import android.content.ComponentName

class WalletDaysWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, WalletDaysWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    private fun updateWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(
                context.packageName,
                R.layout.wallet_days_widget
            )

            val prefs = HomeWidgetPlugin.getData(context)
            val remainingText = prefs.getString("remaining_amount_text", "0円") ?: "0円"
            val remainingBudget = prefs.getInt("remaining_budget", 0)
            val totalBudget = prefs.getInt("total_budget", 0)

            val remainingTitle = prefs.getString("quick_add_remaining_title", "今月あと") ?: "今月あと"

            val danger1Name = prefs.getString("danger_category_1_name", "") ?: ""
            val danger1Remaining = prefs.getInt("danger_category_1_remaining", 0)
            val danger1Badge = prefs.getString("danger_category_1_badge", "") ?: ""

            val danger2Name = prefs.getString("danger_category_2_name", "") ?: ""
            val danger2Remaining = prefs.getInt("danger_category_2_remaining", 0)
            val danger2Badge = prefs.getString("danger_category_2_badge", "") ?: ""

            val widgetLang = prefs.getString("widget_lang", "") ?: ""
            val isEnglish = widgetLang == "en" ||
                remainingText.startsWith("$") ||
                remainingTitle.contains("Remaining", ignoreCase = true)

            fun formatMoney(amount: Int): String {
                return if (isEnglish) {
                    String.format("$%,.2f", amount / 100.0)
                } else {
                    String.format("%,d円", amount)
                }
            }

            fun usageText(remaining: Int, total: Int): String {
                val used = total - remaining
                return "${formatMoney(used)} / ${formatMoney(total)}"
            }

            fun usagePercent(remaining: Int, total: Int): Int {
                if (total <= 0) return 0
                val used = (total - remaining).coerceAtLeast(0)
                val percent = (used.toDouble() / total.toDouble() * 100.0).toInt()
                return percent.coerceIn(0, 100)
            }

            fun dangerText(name: String, remaining: Int, badge: String): String {
                val prefix = if (badge.isBlank()) "•" else badge
                return if (isEnglish) {
                    "$prefix $name left ${formatMoney(remaining)}"
                } else {
                    "$prefix $name あと${formatMoney(remaining)}"
                }
            }

            views.setTextViewText(
                R.id.widget_remaining_title,
                remainingTitle
            )

            views.setTextViewText(
                R.id.widget_remaining_budget,
                remainingText
            )

            views.setTextViewText(
                R.id.widget_usage_text,
                usageText(remainingBudget, totalBudget)
            )

            views.setProgressBar(
                R.id.widget_progress_bar,
                100,
                usagePercent(remainingBudget, totalBudget),
                false
            )

            if (danger1Name.isNotBlank()) {
                views.setTextViewText(
                    R.id.widget_danger_1,
                    dangerText(danger1Name, danger1Remaining, danger1Badge)
                )
                views.setViewVisibility(R.id.widget_danger_1, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_danger_1, View.GONE)
            }

            if (danger2Name.isNotBlank()) {
                views.setTextViewText(
                    R.id.widget_danger_2,
                    dangerText(danger2Name, danger2Remaining, danger2Badge)
                )
                views.setViewVisibility(R.id.widget_danger_2, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_danger_2, View.GONE)
            }

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                pendingIntent
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
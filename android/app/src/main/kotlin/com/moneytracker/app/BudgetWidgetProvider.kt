package com.moneytracker.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class BudgetWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                    // Get data from widget storage
                    val monthName = widgetData.getString("month_name", null) ?: getCurrentMonthName()
                    val expenses = widgetData.getString("expenses", "\$0.00") ?: "\$0.00"
                    val income = widgetData.getString("income", "\$0.00") ?: "\$0.00"
                    val balance = widgetData.getString("balance", "\$0.00") ?: "\$0.00"
                    val isPositive = widgetData.getBoolean("is_positive", true)

                    // Update text views
                    setTextViewText(R.id.widget_month, monthName)
                    setTextViewText(R.id.widget_expenses, expenses)
                    setTextViewText(R.id.widget_income, income)
                    setTextViewText(R.id.widget_balance, balance)

                    // Set balance color based on positive/negative
                    val balanceColor = if (isPositive) 0xFF4CAF50.toInt() else 0xFFF44336.toInt()
                    setTextColor(R.id.widget_balance, balanceColor)

                    // Set up click handler to open the app
                    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (intent != null) {
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)
                        setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                // Log error but don't crash the widget
                android.util.Log.e("BudgetWidgetProvider", "Error updating widget: ${e.message}")
            }
        }
    }

    private fun getCurrentMonthName(): String {
        val months = arrayOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        )
        val calendar = java.util.Calendar.getInstance()
        return months[calendar.get(java.util.Calendar.MONTH)]
    }
}

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
                // Read data from the SharedPreferences provided by HomeWidgetProvider.
                // If that has no data, fall back to reading directly from the known
                // SharedPreferences file used by the home_widget plugin.
                val data = if (widgetData.getString("month_name", null) != null) {
                    widgetData
                } else {
                    context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                }

                val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                    val monthName = data.getString("month_name", null) ?: getCurrentMonthName()
                    val expenses = data.getString("expenses", null) ?: "\$0.00"
                    val income = data.getString("income", null) ?: "\$0.00"
                    val balance = data.getString("balance", null) ?: "\$0.00"
                    val isPositive = data.getBoolean("is_positive", true)

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
                // On error, still try to show a basic widget with defaults
                android.util.Log.e("BudgetWidgetProvider", "Error updating widget: ${e.message}", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                        setTextViewText(R.id.widget_month, getCurrentMonthName())
                        setTextViewText(R.id.widget_expenses, "\$0.00")
                        setTextViewText(R.id.widget_income, "\$0.00")
                        setTextViewText(R.id.widget_balance, "\$0.00")
                        setTextColor(R.id.widget_balance, 0xFF4CAF50.toInt())
                    }
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (fallbackError: Exception) {
                    android.util.Log.e("BudgetWidgetProvider", "Fallback update also failed: ${fallbackError.message}")
                }
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

package com.moneytracker.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Home-screen widget: this month's balance, income and expenses, plus
 * one-tap Add Expense / Add Income.
 *
 * The Flutter side (lib/utils/home_widget_helper.dart) publishes the figures
 * for the current month AND the next one. This class picks whichever matches
 * the device clock, so after midnight on the 1st the widget shows the new
 * month on its next periodic update even if the app has not been opened —
 * instead of last month's numbers. Anything older shows dashes until the app
 * runs again.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                widgetId,
                buildViews(context, appWidgetManager, widgetId, widgetData),
            )
        }
    }

    // Before Android 12 a resize only arrives here, and the layout has to be
    // re-picked by hand. From 12 on the size-mapped RemoteViews below already
    // follow the size; re-rendering is harmless.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context)),
        )
    }

    private fun buildViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ): RemoteViews {
        val figures = Figures.from(data, Calendar.getInstance())
        val purple = data.getString("theme_mode", null) == "purple"
        val compact = render(context, R.layout.budget_widget_compact, figures, purple)
        val full = render(context, R.layout.budget_widget, figures, purple)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // The launcher shows the largest entry that fits the widget.
            return RemoteViews(
                mapOf(
                    SizeF(100f, 40f) to compact,
                    SizeF(150f, FULL_LAYOUT_MIN_HEIGHT_DP) to full,
                ),
            )
        }
        // Pre-12 launchers report the portrait height as the max height.
        val height = appWidgetManager.getAppWidgetOptions(widgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return if (height in 1 until FULL_LAYOUT_MIN_HEIGHT_DP.toInt()) compact else full
    }

    private fun render(
        context: Context,
        layoutId: Int,
        figures: Figures,
        purple: Boolean,
    ): RemoteViews {
        return RemoteViews(context.packageName, layoutId).apply {
            paint(full = layoutId == R.layout.budget_widget, purple = purple)
            setTextViewText(
                R.id.widget_month,
                context.getString(R.string.widget_balance_label, figures.monthName),
            )
            setTextViewText(R.id.widget_balance, figures.balance)
            if (layoutId == R.layout.budget_widget) {
                setTextViewText(R.id.widget_income, figures.income)
                setTextViewText(R.id.widget_expenses, figures.expenses)
            }
            // The widget body just opens the app; the buttons open the Add
            // form. Distinct URIs keep the three PendingIntents distinct.
            setOnClickPendingIntent(
                android.R.id.background,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            setOnClickPendingIntent(
                R.id.widget_add_expense,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    quickAddUri("expense"),
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_add_income,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    quickAddUri("income"),
                ),
            )
        }
    }

    /**
     * The neutral tile, or Purple's violet one when the app is in Purple.
     * Every colour involved has a night variant and is resolved by the
     * launcher when it inflates the views, so the tile follows day/night like
     * the app does. Backgrounds swap on every Android version. Text only
     * recolours from Android 12, the first with `setColor` (a colour resource
     * resolved at inflation); a colour baked in here would go stale at the
     * next day/night switch. Before 12 the text keeps the neutral ink, which
     * clears 4.5:1 on both violet tiles.
     *
     * Both palettes are painted explicitly, never left to the XML: a launcher
     * re-applies an update onto the views it already inflated when the layout
     * is unchanged, so a property set for Purple stays until it is set back.
     */
    private fun RemoteViews.paint(full: Boolean, purple: Boolean) {
        setInt(
            android.R.id.background,
            "setBackgroundResource",
            if (purple) R.drawable.widget_background_purple else R.drawable.widget_background,
        )
        val button = when {
            full && purple -> R.drawable.widget_button_background_purple
            full -> R.drawable.widget_button_background
            purple -> R.drawable.widget_round_button_background_purple
            else -> R.drawable.widget_round_button_background
        }
        setInt(R.id.widget_add_expense, "setBackgroundResource", button)
        setInt(R.id.widget_add_income, "setBackgroundResource", button)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val ink = if (purple) R.color.widget_purple_on_surface else R.color.widget_on_surface
            val secondary = if (purple) {
                R.color.widget_purple_on_surface_variant
            } else {
                R.color.widget_on_surface_variant
            }
            setColor(R.id.widget_month, "setTextColor", secondary)
            setColor(R.id.widget_balance, "setTextColor", ink)
            if (full) {
                setColor(R.id.widget_income_label, "setTextColor", secondary)
                setColor(R.id.widget_expenses_label, "setTextColor", secondary)
                setColor(R.id.widget_income, "setTextColor", ink)
                setColor(R.id.widget_expenses, "setTextColor", ink)
                setColor(R.id.widget_add_expense_label, "setTextColor", ink)
                setColor(R.id.widget_add_income_label, "setTextColor", ink)
            }
        }
    }

    /** One month's figures, already formatted (and redacted) by the app. */
    private class Figures(
        val monthName: String,
        val balance: String,
        val income: String,
        val expenses: String,
    ) {
        companion object {
            fun from(data: SharedPreferences, now: Calendar): Figures {
                val currentKey = String.format(
                    Locale.US,
                    "%04d-%02d",
                    now.get(Calendar.YEAR),
                    now.get(Calendar.MONTH) + 1,
                )
                val prefix = when (currentKey) {
                    data.getString("month_key", null) -> ""
                    data.getString("next_month_key", null) -> "next_"
                    else -> null
                }
                // English like the rest of the app's copy.
                val clockMonth = SimpleDateFormat("MMMM", Locale.ENGLISH).format(now.time)
                if (prefix == null) {
                    return Figures(clockMonth, NO_DATA, NO_DATA, NO_DATA)
                }
                return Figures(
                    monthName = data.getString("${prefix}month_name", null) ?: clockMonth,
                    balance = data.getString("${prefix}balance", null) ?: NO_DATA,
                    income = data.getString("${prefix}income", null) ?: NO_DATA,
                    expenses = data.getString("${prefix}expenses", null) ?: NO_DATA,
                )
            }
        }
    }

    companion object {
        /** Shorter than this, the compact one-row layout is used. */
        private const val FULL_LAYOUT_MIN_HEIGHT_DP = 185f

        /** Shown for an amount the app has not published for this month. */
        private const val NO_DATA = "—"

        /** Must match HomeWidgetHelper.quickAddType on the Flutter side. */
        private fun quickAddUri(type: String): Uri = Uri.parse("financeflow://add?type=$type")
    }
}

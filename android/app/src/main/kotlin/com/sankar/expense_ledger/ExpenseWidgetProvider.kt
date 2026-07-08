package com.sankar.expense_ledger

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class ExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val recentTransactions = widgetData.getString("recent_transactions", "No recent transactions")
            views.setTextViewText(R.id.widget_transactions, recentTransactions)

            // Intent to open the app with a specific URI (e.g., to add an expense)
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("expense_ledger://add_expense")
            )
            views.setOnClickPendingIntent(R.id.btn_add_expense, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

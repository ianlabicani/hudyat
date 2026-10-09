package com.example.hudyat

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import java.util.Date

/**
 * The home screen widget: how many of the last 7 days' texts were checked
 * as "Mukhang scam", "Mag-ingat" or a gambling promo. Numbers only, since a
 * home screen is visible to anyone holding the phone.
 */
class ScamWidget : AppWidgetProvider() {
    // Drawn from the numbers the last check saved. The check itself runs on
    // the 12-hour alarm and whenever Hudyat is opened.
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        redraw(context.applicationContext)
    }

    companion object {
        fun redraw(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScamWidget::class.java))
            if (ids.isEmpty()) return
            val counts = InboxCheck.counts(context)
            val views = RemoteViews(context.packageName, R.layout.scam_widget)
            val message = when {
                counts.state == InboxCheck.NO_ACCESS -> "Open Hudyat to check your texts"
                counts.state == InboxCheck.NOT_CHECKED -> "Not checked yet. Open Hudyat."
                counts.scam + counts.caution + counts.gambling == 0 ->
                    "Walang nakitang scam sa huling 7 araw"
                else -> null
            }
            views.setViewVisibility(R.id.widget_counts, if (message == null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_message, if (message == null) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_message, message ?: "")
            views.setTextViewText(R.id.widget_scam, counts.scam.toString())
            views.setTextViewText(R.id.widget_caution, counts.caution.toString())
            views.setTextViewText(R.id.widget_gambling, counts.gambling.toString())
            views.setTextViewText(
                R.id.widget_footer,
                if (counts.state != InboxCheck.CHECKED) {
                    ""
                } else {
                    val time = DateFormat.getTimeFormat(context).format(Date(counts.checkedAt))
                    "7-day SMS · ${counts.total} checked · $time"
                },
            )
            views.setOnClickPendingIntent(R.id.widget_root, InboxCheck.openFlagged(context, 4401))
            manager.updateAppWidget(ids, views)
        }
    }
}

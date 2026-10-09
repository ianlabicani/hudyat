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

    /** What the tile says when it has no counts to show. */
    private class Message(val title: Int, val icon: Int, val detail: Int? = null)

    companion object {
        fun redraw(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScamWidget::class.java))
            if (ids.isEmpty()) return
            val counts = InboxCheck.counts(context)
            val views = RemoteViews(context.packageName, R.layout.scam_widget)
            // A message with its icon stands in for the counts: a tile of
            // three zeros says less than "nothing found".
            val message = when {
                counts.state == InboxCheck.NO_ACCESS ->
                    Message(R.string.widget_no_access, R.drawable.ic_widget_locked)
                counts.state == InboxCheck.NOT_CHECKED ->
                    Message(R.string.widget_not_checked, R.drawable.ic_widget_waiting)
                counts.scam + counts.caution + counts.gambling == 0 -> Message(
                    R.string.widget_clear,
                    R.drawable.ic_widget_clear,
                    R.string.widget_clear_detail,
                )
                else -> null
            }
            views.setViewVisibility(R.id.widget_counts, if (message == null) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_message, if (message == null) View.GONE else View.VISIBLE)
            if (message != null) {
                views.setImageViewResource(R.id.widget_message_icon, message.icon)
                views.setTextViewText(R.id.widget_message_title, context.getString(message.title))
                views.setTextViewText(
                    R.id.widget_message_detail,
                    message.detail?.let(context::getString) ?: "",
                )
                views.setViewVisibility(
                    R.id.widget_message_detail,
                    if (message.detail == null) View.GONE else View.VISIBLE,
                )
            }
            views.setTextViewText(R.id.widget_scam, counts.scam.toString())
            views.setTextViewText(R.id.widget_caution, counts.caution.toString())
            views.setTextViewText(R.id.widget_gambling, counts.gambling.toString())
            views.setTextViewText(
                R.id.widget_footer,
                if (counts.state != InboxCheck.CHECKED) {
                    ""
                } else {
                    val time = DateFormat.getTimeFormat(context).format(Date(counts.checkedAt))
                    context.getString(R.string.widget_footer, counts.total, time)
                },
            )
            views.setOnClickPendingIntent(R.id.widget_root, InboxCheck.openFlagged(context, 4401))
            manager.updateAppWidget(ids, views)
        }
    }
}

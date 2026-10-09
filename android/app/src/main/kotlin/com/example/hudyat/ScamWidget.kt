package com.example.hudyat

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.text.format.DateFormat
import android.util.TypedValue
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

    // Resized on the home screen: lay the tile out again for its new size.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        redraw(context.applicationContext)
    }

    /** What the tile says when it has no counts to show. */
    private class Message(val title: Int, val icon: Int, val detail: Int? = null)

    companion object {
        /** Below this width the full verdict words do not fit beside the numbers. */
        private const val NARROW_BELOW_DP = 290

        /** Below this height the footer is dropped and the headline shrinks. */
        private const val SHORT_BELOW_DP = 140

        fun redraw(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScamWidget::class.java))
            if (ids.isEmpty()) return
            val counts = InboxCheck.counts(context)
            // Each tile on the home screen can be a different size.
            for (id in ids) manager.updateAppWidget(id, views(context, counts, manager, id))
        }

        private fun views(
            context: Context,
            counts: InboxCheck.Counts,
            manager: AppWidgetManager,
            id: Int,
        ): RemoteViews {
            // In portrait the tile is its minimum width and maximum height.
            // Zero means the launcher did not say: lay out at full size.
            val options = manager.getAppWidgetOptions(id)
            val narrow = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) in
                1 until NARROW_BELOW_DP
            val short = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) in
                1 until SHORT_BELOW_DP
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

            // A narrow tile keeps every number and shortens the words.
            views.setTextViewText(
                R.id.widget_scam_label,
                context.getString(if (narrow) R.string.widget_scam_short else R.string.widget_scam),
            )
            views.setTextViewText(
                R.id.widget_caution_label,
                context.getString(
                    if (narrow) R.string.widget_caution_short else R.string.widget_caution,
                ),
            )
            views.setTextViewText(
                R.id.widget_gambling_label,
                context.getString(
                    if (narrow) R.string.widget_gambling_short else R.string.widget_gambling,
                ),
            )
            views.setViewVisibility(R.id.widget_period, if (narrow) View.GONE else View.VISIBLE)
            views.setTextViewTextSize(
                R.id.widget_scam,
                TypedValue.COMPLEX_UNIT_DIP,
                if (short) 36f else 48f,
            )

            val footer = if (counts.state != InboxCheck.CHECKED) {
                ""
            } else {
                val time = DateFormat.getTimeFormat(context).format(Date(counts.checkedAt))
                context.getString(R.string.widget_footer, counts.total, time)
            }
            views.setTextViewText(R.id.widget_footer, footer)
            views.setViewVisibility(R.id.widget_footer, if (short) View.GONE else View.VISIBLE)

            // One sentence for a screen reader, in place of loose numbers.
            views.setContentDescription(
                R.id.widget_root,
                if (message != null) {
                    context.getString(
                        R.string.widget_summary_message,
                        listOfNotNull(message.title, message.detail)
                            .joinToString(" ") { context.getString(it) },
                    )
                } else {
                    context.getString(
                        R.string.widget_summary,
                        counts.scam,
                        counts.caution,
                        counts.gambling,
                        footer,
                    )
                },
            )
            views.setOnClickPendingIntent(R.id.widget_root, InboxCheck.openFlagged(context, 4401))
            return views
        }
    }
}

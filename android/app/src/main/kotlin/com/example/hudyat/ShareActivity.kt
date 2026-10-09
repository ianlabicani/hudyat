package com.example.hudyat

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives text from the share sheet and from "Check with Hudyat" in the text
 * selection menu, passes it to the one running MainActivity and closes. It
 * has no screen of its own, so a second copy of the app (and its models) is
 * never started inside the other app's task.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = when (intent?.action) {
            Intent.ACTION_SEND -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_PROCESS_TEXT -> intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
            else -> null
        }
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                action = MainActivity.ACTION_CHECK
                putExtra(MainActivity.EXTRA_TEXT, text?.toString() ?: "")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        finish()
    }
}

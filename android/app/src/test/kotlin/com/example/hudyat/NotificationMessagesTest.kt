package com.example.hudyat

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Outgoing previews and empty content never reach the checker. */
class NotificationMessagesTest {
    @Test
    fun incomingTextPasses() {
        assertTrue(NotificationMessages.isIncomingText("Claim your prize now"))
        assertTrue(NotificationMessages.isIncomingText("Youthful offers today"))
    }

    @Test
    fun outgoingPreviewsAreExcluded() {
        assertFalse(NotificationMessages.isIncomingText("You: sige, see you"))
        assertFalse(NotificationMessages.isIncomingText("you: lowercase too"))
        assertFalse(NotificationMessages.isIncomingText("Me: on my way"))
        assertFalse(NotificationMessages.isIncomingText("You sent a photo"))
    }

    @Test
    fun emptyContentIsExcluded() {
        assertFalse(NotificationMessages.isIncomingText(""))
    }
}

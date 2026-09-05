package org.relayline.ui

import org.relayline.transport.BluetoothAccessState
import org.relayline.transport.NearbyMeshStatus

enum class ConversationKind {
    ROOM,
    DIRECT,
}

data class Conversation(
    val id: String,
    val title: String,
    val subtitle: String,
    val kind: ConversationKind,
    val unreadCount: Int = 0,
)

enum class MessageDirection {
    INCOMING,
    OUTGOING,
    SYSTEM,
}

data class ChatMessage(
    val id: Long,
    val author: String,
    val body: String,
    val sentAt: String,
    val direction: MessageDirection,
    /** A local state label, never an asserted delivery receipt. */
    val stateLabel: String? = null,
)

data class RelaylineUiState(
    val conversations: List<Conversation> = sampleConversations,
    val selectedConversationId: String = "lobby",
    val messagesByConversation: Map<String, List<ChatMessage>> = sampleMessages,
    val composer: String = "",
    val nearbyEnabled: Boolean = false,
    val bluetoothAccess: BluetoothAccessState = BluetoothAccessState.PermissionRequired(emptyList()),
    val nearbyStatus: NearbyMeshStatus = NearbyMeshStatus.Stopped,
    val globalRelayEnabled: Boolean = false,
) {
    val selectedConversation: Conversation
        get() = conversations.firstOrNull { it.id == selectedConversationId } ?: conversations.first()

    val selectedMessages: List<ChatMessage>
        get() = messagesByConversation[selectedConversationId].orEmpty()
}

private val sampleConversations = listOf(
    Conversation(
        id = "lobby",
        title = "#lobby",
        subtitle = "Local workspace",
        kind = ConversationKind.ROOM,
    ),
    Conversation(
        id = "geo:te7",
        title = "#te7",
        subtitle = "Location room · coarse",
        kind = ConversationKind.ROOM,
    ),
    Conversation(
        id = "guide",
        title = "relayline-guide",
        subtitle = "Getting started",
        kind = ConversationKind.DIRECT,
        unreadCount = 1,
    ),
)

private val sampleMessages = mapOf(
    "lobby" to listOf(
        ChatMessage(
            id = 1,
            author = "relayline",
            body = "Welcome. No account is required; this starter displays a placeholder device ID.",
            sentAt = "now",
            direction = MessageDirection.SYSTEM,
        ),
        ChatMessage(
            id = 2,
            author = "relayline",
            body = "Use /help for IRC-style commands. Nearby radio stays off until you enable it.",
            sentAt = "now",
            direction = MessageDirection.SYSTEM,
        ),
    ),
    "geo:te7" to listOf(
        ChatMessage(
            id = 3,
            author = "relayline",
            body = "#te7 is a coarse example location room. Joining a room should be explicit.",
            sentAt = "now",
            direction = MessageDirection.SYSTEM,
        ),
    ),
    "guide" to listOf(
        ChatMessage(
            id = 4,
            author = "guide",
            body = "Direct-message transport is not wired in this starter yet.",
            sentAt = "now",
            direction = MessageDirection.INCOMING,
        ),
    ),
)

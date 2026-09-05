package org.relayline.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.relayline.transport.AndroidBlePresenceTransport
import org.relayline.transport.BluetoothAccessState
import org.relayline.transport.BluetoothPermissionPolicy
import org.relayline.transport.NearbyMeshStatus

/**
 * UI-only starter state. Its messages are intentionally local drafts until a
 * shared protocol client and a reviewed transport bearer are connected.
 */
class RelaylineViewModel(application: Application) : AndroidViewModel(application) {
    private val nearbyTransport = AndroidBlePresenceTransport(application)
    private var nextMessageId = 100L

    private val _uiState = MutableStateFlow(
        RelaylineUiState(
            bluetoothAccess = BluetoothPermissionPolicy.evaluate(application),
        ),
    )
    val uiState = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            nearbyTransport.status.collect { status ->
                _uiState.update {
                        it.copy(
                            nearbyStatus = status,
                            bluetoothAccess = BluetoothPermissionPolicy.evaluate(getApplication<Application>()),
                    )
                }
            }
        }
    }

    fun refreshBluetoothAccess() {
        val access = BluetoothPermissionPolicy.evaluate(getApplication<Application>())
        _uiState.update { it.copy(bluetoothAccess = access) }
        if (_uiState.value.nearbyEnabled && access is BluetoothAccessState.Ready) {
            startNearby()
        }
    }

    fun setNearbyEnabled(enabled: Boolean) {
        _uiState.update { it.copy(nearbyEnabled = enabled) }
        if (enabled) {
            if (_uiState.value.bluetoothAccess is BluetoothAccessState.Ready) startNearby()
        } else {
            viewModelScope.launch { nearbyTransport.stop() }
        }
    }

    fun selectConversation(id: String) {
        _uiState.update { current ->
            current.copy(
                selectedConversationId = id,
                conversations = current.conversations.map { conversation ->
                    if (conversation.id == id) conversation.copy(unreadCount = 0) else conversation
                },
            )
        }
    }

    fun updateComposer(value: String) {
        _uiState.update { it.copy(composer = value) }
    }

    fun sendComposer() {
        val input = _uiState.value.composer.trim()
        if (input.isEmpty()) return

        if (input.startsWith('/')) {
            runCommand(input)
        } else {
            appendMessage(
                author = "you",
                body = input,
                direction = MessageDirection.OUTGOING,
                stateLabel = "local draft",
            )
        }
        _uiState.update { it.copy(composer = "") }
    }

    private fun startNearby() {
        viewModelScope.launch { nearbyTransport.start() }
    }

    private fun runCommand(rawCommand: String) {
        val parts = rawCommand.drop(1).split(Regex("\\s+"), limit = 2)
        val command = parts.firstOrNull()?.lowercase().orEmpty()
        val arguments = parts.getOrNull(1).orEmpty()

        when (command) {
            "help" -> appendSystem(
                "/join <geohash> · /leave [room] · /msg <npub> <text> · /me <action> · /who [room] · /offline",
            )

            "join" -> joinLocationRoom(arguments)
            "leave" -> leaveRoom(arguments)
            "me" -> {
                if (arguments.isBlank()) appendSystem("Usage: /me <action>")
                else appendMessage("you", "* you $arguments", MessageDirection.OUTGOING, "local draft")
            }

            "msg" -> appendSystem(
                if (arguments.split(Regex("\\s+"), limit = 2).size < 2) {
                    "Usage: /msg <npub> <text>"
                } else {
                    "Direct-message sending needs the shared protocol client before it can leave this device."
                },
            )

            "who" -> appendSystem(
                "Presence is not exposed by default. Nearby discovery only counts anonymous radio signals in this starter.",
            )

            "offline" -> {
                _uiState.update { it.copy(globalRelayEnabled = false) }
                appendSystem("Global relay mode is off. No relay connection is active in this starter.")
            }

            "relay" -> appendSystem("Relay configuration is reserved for the future Nostr client.")
            else -> appendSystem("Unknown command: /$command. Try /help.")
        }
    }

    private fun joinLocationRoom(rawGeohash: String) {
        val geohash = rawGeohash.lowercase()
        val isGeohash = geohash.matches(Regex("[0123456789bcdefghjkmnpqrstuvwxyz]{1,12}"))
        if (!isGeohash) {
            appendSystem("Usage: /join <geohash> (1–12 geohash characters)")
            return
        }

        val id = "geo:$geohash"
        _uiState.update { current ->
            val room = Conversation(
                id = id,
                title = "#$geohash",
                subtitle = "Location room · explicit join",
                kind = ConversationKind.ROOM,
            )
            val existing = current.conversations.any { it.id == id }
            current.copy(
                conversations = if (existing) current.conversations else current.conversations + room,
                selectedConversationId = id,
                messagesByConversation = if (current.messagesByConversation.containsKey(id)) {
                    current.messagesByConversation
                } else {
                    current.messagesByConversation + (
                        id to listOf(
                            nextSystemMessage("Joined #$geohash locally. A room is not a delivery channel until a transport is connected."),
                        )
                    )
                },
            )
        }
    }

    private fun leaveRoom(argument: String) {
        val current = _uiState.value
        val selectedId = current.selectedConversationId
        val target = argument.removePrefix("#").ifBlank {
            current.selectedConversation.title.removePrefix("#")
        }
        val id = if (argument.isBlank()) selectedId else if (target.startsWith("geo:")) target else "geo:$target"
        if (id !in current.conversations.map { it.id }) {
            appendSystem("You have not joined #$target.")
            return
        }
        if (id == "lobby") {
            appendSystem("#lobby is the local starter room and cannot be left.")
            return
        }
        _uiState.update { state ->
            state.copy(
                conversations = state.conversations.filterNot { it.id == id },
                selectedConversationId = "lobby",
                messagesByConversation = state.messagesByConversation - id,
            )
        }
        appendSystem("Left #$target locally.")
    }

    private fun appendSystem(body: String) {
        appendMessage("relayline", body, MessageDirection.SYSTEM)
    }

    private fun appendMessage(
        author: String,
        body: String,
        direction: MessageDirection,
        stateLabel: String? = null,
    ) {
        _uiState.update { current ->
            val roomId = current.selectedConversationId
            val message = nextSystemMessage(body).copy(
                author = author,
                direction = direction,
                stateLabel = stateLabel,
            )
            current.copy(
                messagesByConversation = current.messagesByConversation + (
                    roomId to (current.messagesByConversation[roomId].orEmpty() + message)
                ),
            )
        }
    }

    private fun nextSystemMessage(body: String): ChatMessage = ChatMessage(
        id = nextMessageId++,
        author = "relayline",
        body = body,
        sentAt = "now",
        direction = MessageDirection.SYSTEM,
    )

    override fun onCleared() {
        nearbyTransport.stopImmediately()
        super.onCleared()
    }
}

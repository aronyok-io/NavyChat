package org.relayline.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.relayline.transport.BluetoothAccessState
import org.relayline.transport.NearbyMeshStatus

@Composable
fun RelaylineApp(
    state: RelaylineUiState,
    onSelectConversation: (String) -> Unit,
    onComposerChanged: (String) -> Unit,
    onSend: () -> Unit,
    onNearbyToggled: (Boolean) -> Unit,
    onRequestNearbyPermission: () -> Unit,
    onOpenBluetoothSettings: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = RelaylineColors.Night,
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val isWide = maxWidth >= 760.dp
            if (isWide) {
                Row(modifier = Modifier.fillMaxSize()) {
                    ConversationRail(
                        state = state,
                        onSelectConversation = onSelectConversation,
                        onNearbyToggled = onNearbyToggled,
                        onRequestNearbyPermission = onRequestNearbyPermission,
                        onOpenBluetoothSettings = onOpenBluetoothSettings,
                        modifier = Modifier
                            .width(292.dp)
                            .fillMaxHeight(),
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .fillMaxHeight()
                            .background(RelaylineColors.Border),
                    )
                    ChatPanel(
                        state = state,
                        onComposerChanged = onComposerChanged,
                        onSend = onSend,
                        modifier = Modifier.weight(1f),
                    )
                }
            } else {
                Column(modifier = Modifier.fillMaxSize()) {
                    CompactHeader(state = state)
                    ConversationStrip(
                        state = state,
                        onSelectConversation = onSelectConversation,
                    )
                    NearbyCard(
                        state = state,
                        onNearbyToggled = onNearbyToggled,
                        onRequestNearbyPermission = onRequestNearbyPermission,
                        onOpenBluetoothSettings = onOpenBluetoothSettings,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                    ChatPanel(
                        state = state,
                        onComposerChanged = onComposerChanged,
                        onSend = onSend,
                        modifier = Modifier.weight(1f),
                        showNearbyHint = false,
                    )
                }
            }
        }
    }
}

@Composable
private fun ConversationRail(
    state: RelaylineUiState,
    onSelectConversation: (String) -> Unit,
    onNearbyToggled: (Boolean) -> Unit,
    onRequestNearbyPermission: () -> Unit,
    onOpenBluetoothSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(horizontal = 12.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        BrandLockup()
        StatusLine(state = state)
        NearbyCard(
            state = state,
            onNearbyToggled = onNearbyToggled,
            onRequestNearbyPermission = onRequestNearbyPermission,
            onOpenBluetoothSettings = onOpenBluetoothSettings,
        )
        Text(
            text = "CONVERSATIONS",
            style = MaterialTheme.typography.labelSmall,
            color = RelaylineColors.Muted,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.padding(top = 6.dp, start = 6.dp),
        )
        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            contentPadding = PaddingValues(bottom = 8.dp),
        ) {
            items(state.conversations, key = { it.id }) { conversation ->
                ConversationRow(
                    conversation = conversation,
                    selected = conversation.id == state.selectedConversationId,
                    onClick = { onSelectConversation(conversation.id) },
                )
            }
        }
        IdentityFootnote()
    }
}

@Composable
private fun CompactHeader(state: RelaylineUiState) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BrandLockup(compact = true)
        StatusPill(
            label = when (state.nearbyStatus) {
                is NearbyMeshStatus.Discovering -> "MESH"
                else -> "LOCAL"
            },
            color = if (state.nearbyStatus is NearbyMeshStatus.Discovering) {
                RelaylineColors.Success
            } else {
                RelaylineColors.Muted
            },
        )
    }
}

@Composable
private fun BrandLockup(compact: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(if (compact) 30.dp else 36.dp)
                .clip(RoundedCornerShape(11.dp))
                .background(RelaylineColors.Signal),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "R",
                color = RelaylineColors.Night,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace,
            )
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(
                text = "relayline",
                style = if (compact) MaterialTheme.typography.titleMedium else MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = RelaylineColors.Ink,
            )
            if (!compact) {
                Text(
                    text = "OFFLINE-FIRST CHAT",
                    style = MaterialTheme.typography.labelSmall,
                    fontFamily = FontFamily.Monospace,
                    color = RelaylineColors.Muted,
                )
            }
        }
    }
}

@Composable
private fun StatusLine(state: RelaylineUiState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        StatusPill(
            label = if (state.globalRelayEnabled) "RELAY" else "NO RELAY",
            color = if (state.globalRelayEnabled) RelaylineColors.Success else RelaylineColors.Muted,
        )
        StatusPill(
            label = when (state.nearbyStatus) {
                is NearbyMeshStatus.Discovering -> "MESH ON"
                else -> "MESH OFF"
            },
            color = if (state.nearbyStatus is NearbyMeshStatus.Discovering) {
                RelaylineColors.Success
            } else {
                RelaylineColors.Muted
            },
        )
    }
}

@Composable
private fun StatusPill(label: String, color: Color) {
    Surface(
        color = color.copy(alpha = 0.13f),
        shape = RoundedCornerShape(100.dp),
        border = BorderStroke(1.dp, color.copy(alpha = 0.35f)),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontFamily = FontFamily.Monospace,
            fontWeight = FontWeight.Bold,
            color = color,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
        )
    }
}

@Composable
private fun NearbyCard(
    state: RelaylineUiState,
    onNearbyToggled: (Boolean) -> Unit,
    onRequestNearbyPermission: () -> Unit,
    onOpenBluetoothSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = RelaylineColors.Surface),
        border = BorderStroke(1.dp, RelaylineColors.Border),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Nearby mesh",
                        style = MaterialTheme.typography.titleSmall,
                        color = RelaylineColors.Ink,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = nearbyDetail(state),
                        style = MaterialTheme.typography.bodySmall,
                        color = RelaylineColors.Muted,
                    )
                }
                Switch(
                    checked = state.nearbyEnabled,
                    onCheckedChange = onNearbyToggled,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = RelaylineColors.Night,
                        checkedTrackColor = RelaylineColors.Signal,
                        uncheckedThumbColor = RelaylineColors.Muted,
                        uncheckedTrackColor = RelaylineColors.Border,
                    ),
                )
            }
            val access = state.bluetoothAccess
            if (state.nearbyEnabled && access !is BluetoothAccessState.Ready) {
                Spacer(Modifier.height(10.dp))
                val buttonText = when (access) {
                    is BluetoothAccessState.PermissionRequired -> "Allow nearby access"
                    BluetoothAccessState.BluetoothDisabled -> "Open Bluetooth settings"
                    BluetoothAccessState.Unsupported -> "Unavailable on this device"
                    BluetoothAccessState.Ready -> "Start nearby"
                }
                Button(
                    onClick = {
                        when (access) {
                            is BluetoothAccessState.PermissionRequired -> onRequestNearbyPermission()
                            BluetoothAccessState.BluetoothDisabled -> onOpenBluetoothSettings()
                            BluetoothAccessState.Unsupported, BluetoothAccessState.Ready -> Unit
                        }
                    },
                    enabled = access !is BluetoothAccessState.Unsupported,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RelaylineColors.Signal,
                        contentColor = RelaylineColors.Night,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(buttonText, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

private fun nearbyDetail(state: RelaylineUiState): String = when (val status = state.nearbyStatus) {
    is NearbyMeshStatus.Discovering -> {
        val count = status.nearbySignals
        if (count == 0) "Scanning for nearby Relayline signals."
        else "$count anonymous nearby signal${if (count == 1) "" else "s"} observed."
    }

    is NearbyMeshStatus.NeedsAccess -> status.access.detail
    NearbyMeshStatus.Starting -> "Starting nearby discovery…"
    is NearbyMeshStatus.Stopped -> when (val access = state.bluetoothAccess) {
        BluetoothAccessState.Ready -> "Ready when you are. Bluetooth stays off until enabled."
        else -> access.detail
    }

    is NearbyMeshStatus.Unavailable -> status.reason
    is NearbyMeshStatus.Failed -> status.reason
}

@Composable
private fun ConversationRow(
    conversation: Conversation,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val background = if (selected) RelaylineColors.Signal.copy(alpha = 0.13f) else Color.Transparent
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(11.dp))
            .background(background)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(30.dp)
                .clip(RoundedCornerShape(9.dp))
                .background(if (selected) RelaylineColors.Signal.copy(alpha = 0.2f) else RelaylineColors.RaisedSurface),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (conversation.kind == ConversationKind.ROOM) "#" else "@",
                color = if (selected) RelaylineColors.Bright else RelaylineColors.Muted,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.width(9.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = conversation.title,
                style = MaterialTheme.typography.bodyMedium,
                color = if (selected) RelaylineColors.Bright else RelaylineColors.Ink,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = conversation.subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = RelaylineColors.Muted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (conversation.unreadCount > 0) {
            Surface(
                shape = RoundedCornerShape(100.dp),
                color = RelaylineColors.Signal,
            ) {
                Text(
                    text = conversation.unreadCount.toString(),
                    color = RelaylineColors.Night,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
    }
}

@Composable
private fun IdentityFootnote() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(RelaylineColors.RaisedSurface.copy(alpha = 0.6f))
            .padding(12.dp),
    ) {
        Text(
            text = "YOUR DEVICE ID",
            style = MaterialTheme.typography.labelSmall,
            fontFamily = FontFamily.Monospace,
            color = RelaylineColors.Muted,
        )
        Text(
            text = "rl1 · 7F2A:91C8",
            style = MaterialTheme.typography.bodySmall,
            fontFamily = FontFamily.Monospace,
            color = RelaylineColors.Bright,
        )
        Text(
            text = "Placeholder fingerprint — generate keys locally before release.",
            style = MaterialTheme.typography.labelSmall,
            color = RelaylineColors.Muted,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun ConversationStrip(
    state: RelaylineUiState,
    onSelectConversation: (String) -> Unit,
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp),
        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items(state.conversations.take(4), key = { it.id }) { conversation ->
            Surface(
                shape = RoundedCornerShape(100.dp),
                color = if (conversation.id == state.selectedConversationId) {
                    RelaylineColors.Signal.copy(alpha = 0.17f)
                } else {
                    RelaylineColors.Surface
                },
                border = BorderStroke(
                    1.dp,
                    if (conversation.id == state.selectedConversationId) RelaylineColors.Signal.copy(alpha = 0.55f)
                    else RelaylineColors.Border,
                ),
                modifier = Modifier.clickable { onSelectConversation(conversation.id) },
            ) {
                Text(
                    text = conversation.title,
                    color = if (conversation.id == state.selectedConversationId) {
                        RelaylineColors.Bright
                    } else {
                        RelaylineColors.Muted
                    },
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(horizontal = 11.dp, vertical = 7.dp),
                )
            }
        }
    }
}

@Composable
private fun ChatPanel(
    state: RelaylineUiState,
    onComposerChanged: (String) -> Unit,
    onSend: () -> Unit,
    modifier: Modifier = Modifier,
    showNearbyHint: Boolean = true,
) {
    Column(
        modifier = modifier
            .fillMaxHeight()
            .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = state.selectedConversation.title,
                    style = MaterialTheme.typography.headlineSmall,
                    color = RelaylineColors.Ink,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = state.selectedConversation.subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = RelaylineColors.Muted,
                )
            }
            StatusPill(
                label = if (state.globalRelayEnabled) "RELAY" else "LOCAL ONLY",
                color = if (state.globalRelayEnabled) RelaylineColors.Success else RelaylineColors.Muted,
            )
        }
        Spacer(Modifier.height(14.dp))
        HorizontalDivider(color = RelaylineColors.Border)
        if (showNearbyHint && state.nearbyEnabled) {
            Spacer(Modifier.height(10.dp))
            Text(
                text = "Nearby radio is opt-in. Discovery status is not a message delivery receipt.",
                style = MaterialTheme.typography.labelSmall,
                color = RelaylineColors.Muted,
            )
        }
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentPadding = PaddingValues(vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(state.selectedMessages, key = { it.id }) { message ->
                MessageBubble(message)
            }
        }
        Composer(
            value = state.composer,
            onValueChange = onComposerChanged,
            onSend = onSend,
        )
    }
}

@Composable
private fun MessageBubble(message: ChatMessage) {
    if (message.direction == MessageDirection.SYSTEM) {
        Surface(
            shape = RoundedCornerShape(10.dp),
            color = RelaylineColors.RaisedSurface.copy(alpha = 0.55f),
            border = BorderStroke(1.dp, RelaylineColors.Border.copy(alpha = 0.75f)),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = message.body,
                style = MaterialTheme.typography.bodySmall,
                color = RelaylineColors.Muted,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
            )
        }
        return
    }

    val isOutgoing = message.direction == MessageDirection.OUTGOING
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isOutgoing) Arrangement.End else Arrangement.Start,
    ) {
        Card(
            modifier = Modifier.widthIn(max = 420.dp),
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (isOutgoing) RelaylineColors.Signal.copy(alpha = 0.18f)
                else RelaylineColors.Surface,
            ),
            border = BorderStroke(
                1.dp,
                if (isOutgoing) RelaylineColors.Signal.copy(alpha = 0.45f) else RelaylineColors.Border,
            ),
        ) {
            Column(modifier = Modifier.padding(horizontal = 13.dp, vertical = 10.dp)) {
                Text(
                    text = message.author,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isOutgoing) RelaylineColors.Bright else RelaylineColors.Muted,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(3.dp))
                Text(
                    text = message.body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = RelaylineColors.Ink,
                )
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                    horizontalArrangement = Arrangement.End,
                ) {
                    Text(
                        text = listOfNotNull(message.sentAt, message.stateLabel).joinToString(" · "),
                        style = MaterialTheme.typography.labelSmall,
                        color = RelaylineColors.Muted,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }
        }
    }
}

@Composable
private fun Composer(
    value: String,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = RelaylineColors.Surface,
        border = BorderStroke(1.dp, RelaylineColors.Border),
    ) {
        Column(modifier = Modifier.padding(10.dp)) {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.fillMaxWidth(),
                placeholder = {
                    Text("Message or /command", color = RelaylineColors.Muted)
                },
                textStyle = MaterialTheme.typography.bodyMedium.copy(color = RelaylineColors.Ink),
                minLines = 1,
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { onSend() }),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "/help  /join  /msg",
                    style = MaterialTheme.typography.labelSmall,
                    color = RelaylineColors.Muted,
                    fontFamily = FontFamily.Monospace,
                )
                Button(
                    onClick = onSend,
                    enabled = value.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = RelaylineColors.Signal,
                        contentColor = RelaylineColors.Night,
                        disabledContainerColor = RelaylineColors.Border,
                        disabledContentColor = RelaylineColors.Muted,
                    ),
                ) {
                    Text("Send", fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

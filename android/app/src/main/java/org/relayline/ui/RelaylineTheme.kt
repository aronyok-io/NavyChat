package org.relayline.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object RelaylineColors {
    val Night = Color(0xFF081526)
    val Surface = Color(0xFF10243D)
    val RaisedSurface = Color(0xFF16314F)
    val Border = Color(0xFF244665)
    val Signal = Color(0xFF38BDF8)
    val Bright = Color(0xFF7DD3FC)
    val Ink = Color(0xFFE6F4FF)
    val Muted = Color(0xFF91B4CE)
    val Alert = Color(0xFFFBBF24)
    val Success = Color(0xFF5EEAD4)
}

private val RelaylineScheme = darkColorScheme(
    primary = RelaylineColors.Signal,
    onPrimary = RelaylineColors.Night,
    secondary = RelaylineColors.Bright,
    onSecondary = RelaylineColors.Night,
    background = RelaylineColors.Night,
    onBackground = RelaylineColors.Ink,
    surface = RelaylineColors.Surface,
    onSurface = RelaylineColors.Ink,
    surfaceVariant = RelaylineColors.RaisedSurface,
    onSurfaceVariant = RelaylineColors.Muted,
    outline = RelaylineColors.Border,
    error = RelaylineColors.Alert,
)

@Composable
fun RelaylineTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = RelaylineScheme,
        content = content,
    )
}

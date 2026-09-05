package org.relayline

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import org.relayline.transport.BluetoothPermissionPolicy
import org.relayline.ui.RelaylineApp
import org.relayline.ui.RelaylineTheme
import org.relayline.ui.RelaylineViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            RelaylineTheme {
                val relaylineViewModel: RelaylineViewModel = viewModel()
                val uiState by relaylineViewModel.uiState.collectAsState()
                val permissionLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.RequestMultiplePermissions(),
                ) {
                    relaylineViewModel.refreshBluetoothAccess()
                }

                RelaylineApp(
                    state = uiState,
                    onSelectConversation = relaylineViewModel::selectConversation,
                    onComposerChanged = relaylineViewModel::updateComposer,
                    onSend = relaylineViewModel::sendComposer,
                    onNearbyToggled = relaylineViewModel::setNearbyEnabled,
                    onRequestNearbyPermission = {
                        val permissions = BluetoothPermissionPolicy.requiredRuntimePermissions()
                        if (permissions.isEmpty()) relaylineViewModel.refreshBluetoothAccess()
                        else permissionLauncher.launch(permissions.toTypedArray())
                    },
                    onOpenBluetoothSettings = {
                        startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    },
                )
            }
        }
    }
}

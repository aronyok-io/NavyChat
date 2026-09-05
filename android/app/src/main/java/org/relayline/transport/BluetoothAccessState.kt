package org.relayline.transport

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * A small, testable representation of the conditions Android requires before
 * starting BLE work. It intentionally does not request permissions itself:
 * only a foreground Activity should make that user-facing request.
 */
sealed interface BluetoothAccessState {
    val detail: String

    data object Ready : BluetoothAccessState {
        override val detail = "Bluetooth is ready for nearby discovery."
    }

    data class PermissionRequired(val permissions: List<String>) : BluetoothAccessState {
        override val detail = "Nearby access needs Bluetooth permission."
    }

    data object BluetoothDisabled : BluetoothAccessState {
        override val detail = "Turn Bluetooth on to use nearby discovery."
    }

    data object Unsupported : BluetoothAccessState {
        override val detail = "This device does not support Bluetooth Low Energy."
    }
}

object BluetoothPermissionPolicy {
    /**
     * Android 12+ separates nearby-device permissions from location. Android
     * 11 and older require fine location for BLE scans at the platform level.
     */
    fun requiredRuntimePermissions(sdkInt: Int = Build.VERSION.SDK_INT): List<String> = when {
        sdkInt >= Build.VERSION_CODES.S -> listOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_ADVERTISE,
        )

        sdkInt >= Build.VERSION_CODES.M -> listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        else -> emptyList()
    }

    @SuppressLint("MissingPermission")
    fun evaluate(context: Context): BluetoothAccessState {
        val packageManager = context.packageManager
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            return BluetoothAccessState.Unsupported
        }

        val missing = requiredRuntimePermissions().filter { permission ->
            context.checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            return BluetoothAccessState.PermissionRequired(missing)
        }

        val manager = context.getSystemService(BluetoothManager::class.java)
        val adapter = manager?.adapter ?: return BluetoothAccessState.Unsupported
        return if (adapter.isEnabled) BluetoothAccessState.Ready else BluetoothAccessState.BluetoothDisabled
    }

    fun canUseRadio(state: BluetoothAccessState): Boolean = state is BluetoothAccessState.Ready
}

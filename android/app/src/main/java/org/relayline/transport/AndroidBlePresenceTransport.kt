package org.relayline.transport

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import java.security.SecureRandom
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * BLE discovery scaffolding for the Android host.
 *
 * It broadcasts and scans a tiny, random, rotating-on-start presence marker so
 * the app can prove the permission/lifecycle path without exposing a chat
 * payload, a public key, a location room, or a Bluetooth MAC address. It is
 * deliberately not a finished mesh bearer: opaque envelopes are rejected
 * until a bounded peer-transfer protocol has been implemented and reviewed.
 *
 * A production bearer should use the shared core's packet expiry, duplicate
 * cache, and hop budget. It should establish a reviewed peer link (for
 * example, an explicit GATT transfer protocol) rather than treating BLE
 * advertising as a general-purpose message bus.
 */
class AndroidBlePresenceTransport(context: Context) : NearbyMeshTransport {
    private val appContext = context.applicationContext
    private val lock = Any()
    private val observedSessionTags = mutableSetOf<Int>()

    private val _status = MutableStateFlow<NearbyMeshStatus>(NearbyMeshStatus.Stopped)
    override val status: StateFlow<NearbyMeshStatus> = _status.asStateFlow()

    private var scanner: BluetoothLeScanner? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanCallback: ScanCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var ownSessionTag: Int? = null
    private var running = false

    // The listener is reserved for a future peer bearer. Discovery callbacks
    // intentionally never invoke it because they do not contain a message.
    @Suppress("unused")
    private var packetListener: (suspend (ByteArray) -> Unit)? = null

    @SuppressLint("MissingPermission")
    override suspend fun start(): NearbyMeshStatus = synchronized(lock) {
        val access = BluetoothPermissionPolicy.evaluate(appContext)
        if (!BluetoothPermissionPolicy.canUseRadio(access)) {
            return@synchronized NearbyMeshStatus.NeedsAccess(access).also { _status.value = it }
        }

        if (running) return@synchronized _status.value
        _status.value = NearbyMeshStatus.Starting

        val manager = appContext.getSystemService(BluetoothManager::class.java)
        val adapter = manager?.adapter
        val availableScanner = adapter?.bluetoothLeScanner
        val availableAdvertiser = adapter?.bluetoothLeAdvertiser
        if (availableScanner == null || availableAdvertiser == null) {
            return@synchronized NearbyMeshStatus.Unavailable(
                "This device cannot both scan and advertise Bluetooth Low Energy signals.",
            ).also { _status.value = it }
        }

        val nextScanCallback = discoveryCallback()
        val nextAdvertiseCallback = advertiseCallback()
        val presenceMarker = RelaylinePresenceBeacon.create()
        val presenceData = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceData(RELAYLINE_PRESENCE_SERVICE, presenceMarker)
            .build()
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .build()
        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        val scanFilters = listOf(
            ScanFilter.Builder().setServiceUuid(RELAYLINE_PRESENCE_SERVICE).build(),
        )

        return@synchronized try {
            availableScanner.startScan(scanFilters, scanSettings, nextScanCallback)
            availableAdvertiser.startAdvertising(settings, presenceData, nextAdvertiseCallback)
            scanner = availableScanner
            advertiser = availableAdvertiser
            scanCallback = nextScanCallback
            advertiseCallback = nextAdvertiseCallback
            ownSessionTag = RelaylinePresenceBeacon.decodeSessionTag(presenceMarker)
            observedSessionTags.clear()
            running = true
            NearbyMeshStatus.Discovering(nearbySignals = 0).also { _status.value = it }
        } catch (_: SecurityException) {
            runCatching { availableScanner.stopScan(nextScanCallback) }
            ownSessionTag = null
            NearbyMeshStatus.NeedsAccess(BluetoothPermissionPolicy.evaluate(appContext)).also {
                _status.value = it
            }
        } catch (_: IllegalStateException) {
            runCatching { availableScanner.stopScan(nextScanCallback) }
            ownSessionTag = null
            NearbyMeshStatus.Failed("Bluetooth could not start nearby discovery.").also { _status.value = it }
        }
    }

    override suspend fun stop() {
        stopImmediately()
    }

    /** Safe for lifecycle teardown, including after the view-model scope closes. */
    @SuppressLint("MissingPermission")
    fun stopImmediately() = synchronized(lock) {
        try {
            scanner?.let { activeScanner -> scanCallback?.let(activeScanner::stopScan) }
            advertiser?.let { activeAdvertiser -> advertiseCallback?.let(activeAdvertiser::stopAdvertising) }
        } catch (_: SecurityException) {
            // Permission may be revoked while the app is leaving the foreground.
        } finally {
            scanner = null
            advertiser = null
            scanCallback = null
            advertiseCallback = null
            ownSessionTag = null
            observedSessionTags.clear()
            running = false
            _status.value = NearbyMeshStatus.Stopped
        }
    }

    override suspend fun broadcast(opaqueEnvelope: ByteArray): NearbySendResult {
        if (opaqueEnvelope.isEmpty()) return NearbySendResult.Rejected("Cannot send an empty envelope.")
        if (!running) return NearbySendResult.NotRunning
        return NearbySendResult.Rejected(
            "Nearby discovery is active, but this starter does not yet include a peer message bearer.",
        )
    }

    override fun setPacketListener(listener: suspend (ByteArray) -> Unit) {
        packetListener = listener
    }

    private fun discoveryCallback(): ScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val serviceData = result.scanRecord
                ?.getServiceData(RELAYLINE_PRESENCE_SERVICE)
                ?: return
            val sessionTag = RelaylinePresenceBeacon.decodeSessionTag(serviceData) ?: return

            synchronized(lock) {
                if (!running || sessionTag == ownSessionTag || !observedSessionTags.add(sessionTag)) return
                _status.value = NearbyMeshStatus.Discovering(observedSessionTags.size)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            synchronized(lock) {
                stopImmediately()
                _status.value = NearbyMeshStatus.Failed("Bluetooth scan failed (${scanFailureLabel(errorCode)}).")
            }
        }
    }

    private fun advertiseCallback(): AdvertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            synchronized(lock) {
                stopImmediately()
                _status.value = NearbyMeshStatus.Failed(
                    "Bluetooth advertising failed (${advertiseFailureLabel(errorCode)}).",
                )
            }
        }
    }

    private fun scanFailureLabel(errorCode: Int): String = when (errorCode) {
        ScanCallback.SCAN_FAILED_ALREADY_STARTED -> "already started"
        ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "registration failed"
        ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED -> "feature unsupported"
        ScanCallback.SCAN_FAILED_INTERNAL_ERROR -> "internal error"
        ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES -> "hardware resources unavailable"
        else -> "error $errorCode"
    }

    private fun advertiseFailureLabel(errorCode: Int): String = when (errorCode) {
        AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED -> "already started"
        AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE -> "data too large"
        AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "feature unsupported"
        AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR -> "internal error"
        AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "too many advertisers"
        else -> "error $errorCode"
    }

    private companion object {
        val RELAYLINE_PRESENCE_SERVICE: ParcelUuid = ParcelUuid(
            UUID.fromString("9f44ae70-91ca-4f83-9cad-737b3e4d7a1e"),
        )
    }
}

/** A short, non-identifying BLE presence marker — never a user identity. */
private object RelaylinePresenceBeacon {
    private const val FIRST_MARKER: Byte = 0x52 // R
    private const val SECOND_MARKER: Byte = 0x4c // L
    private const val VERSION: Byte = 0x01
    private const val BYTE_COUNT = 7

    fun create(): ByteArray {
        val sessionTag = SecureRandom().nextInt()
        return byteArrayOf(
            FIRST_MARKER,
            SECOND_MARKER,
            VERSION,
            (sessionTag ushr 24).toByte(),
            (sessionTag ushr 16).toByte(),
            (sessionTag ushr 8).toByte(),
            sessionTag.toByte(),
        )
    }

    fun decodeSessionTag(bytes: ByteArray): Int? {
        if (bytes.size != BYTE_COUNT || bytes[0] != FIRST_MARKER || bytes[1] != SECOND_MARKER) {
            return null
        }
        if (bytes[2] != VERSION) return null

        return ((bytes[3].toInt() and 0xff) shl 24) or
            ((bytes[4].toInt() and 0xff) shl 16) or
            ((bytes[5].toInt() and 0xff) shl 8) or
            (bytes[6].toInt() and 0xff)
    }
}

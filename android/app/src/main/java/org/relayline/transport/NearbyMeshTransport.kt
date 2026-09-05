package org.relayline.transport

import kotlinx.coroutines.flow.StateFlow

/**
 * Boundary between Relayline's platform-neutral routing layer and Android's
 * nearby radio implementation.
 *
 * The transport only handles opaque protocol bytes. It must not parse message
 * text, derive identity from a Bluetooth address, or add its own cryptography.
 * A caller may pass sealed bytes once the shared protocol has established and
 * reviewed its security properties, but this interface alone does not make a
 * message encrypted or authenticated.
 */
interface NearbyMeshTransport {
    val status: StateFlow<NearbyMeshStatus>

    /** Starts only the user-approved nearby radio work. */
    suspend fun start(): NearbyMeshStatus

    suspend fun stop()

    /**
     * Offers an opaque protocol envelope to the active nearby link. A result
     * describes local acceptance only; it is never a delivery receipt.
     */
    suspend fun broadcast(opaqueEnvelope: ByteArray): NearbySendResult

    fun setPacketListener(listener: suspend (ByteArray) -> Unit)
}

sealed interface NearbyMeshStatus {
    data object Stopped : NearbyMeshStatus
    data class NeedsAccess(val access: BluetoothAccessState) : NearbyMeshStatus
    data object Starting : NearbyMeshStatus
    data class Discovering(val nearbySignals: Int) : NearbyMeshStatus
    data class Unavailable(val reason: String) : NearbyMeshStatus
    data class Failed(val reason: String) : NearbyMeshStatus
}

sealed interface NearbySendResult {
    /** The local link accepted a packet for later transmission. */
    data object AcceptedLocally : NearbySendResult

    data object NotRunning : NearbySendResult
    data class Rejected(val reason: String) : NearbySendResult
}

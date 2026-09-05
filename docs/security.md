# Security and privacy design

## Threat model

Relayline should assume relays, nearby forwarders, and local radio observers are untrusted. A device may be stolen; it may replay a packet; it may report a false location; and it may run a modified client.

## Identity

On first launch, generate a device-held signing/encryption key pair. The public key is the user’s identity and can be shared as an `npub` or a QR code. There is no phone-number discovery, central account, contact upload, or directory lookup. Private material remains in OS-protected storage and must be exportable only as an encrypted recovery bundle protected by a user-selected passphrase.

## Encryption

Direct-message content must be end-to-end encrypted before either mesh or Nostr transport sees it. For Nostr delivery, use NIP-44 v2 inside NIP-59 gift wrapping and target NIP-17 semantics where interoperable. NIP-17 is currently a draft, so it must be capability-negotiated rather than treated as an immutable standard. NIP-44 does not itself provide forward secrecy or post-compromise security. Nearby delivery needs a separately reviewed protocol: authenticated encryption, unique nonces, replay cache, key verification UX, ratchet/forward-secrecy plan, and version negotiation.

Never use a home-grown cipher, static shared secret, Bluetooth MAC address as identity, or geohash as a secret.

## Mesh forwarding

Packets carry an opaque ID, expiry, protocol version, and a capped hop budget. A bounded cache suppresses duplicates. Nodes must rate-limit new peers and forwarding; only relay packets users have explicitly allowed under the current battery/data policy. Do not expose a global nearby-member list: presence is a privacy leak.

## Location rooms

A geohash identifies an area, not authorization. Joining a room must be explicit; show its approximate size before joining; default to coarse precision; and do not automatically announce the user’s exact GPS position. Events use an encrypted room key or encrypted invite/epoch-key distribution. Public geohash tags on Nostr are location metadata and must be treated as opt-in public rooms only. A room discoverable from a geohash cannot honestly be marketed as membership-private: Relayline labels these separately as open place rooms and private place circles.

## Before shipping

Commission an independent cryptography review, perform mobile permission/privacy reviews, test radio flood and replay attacks, add abuse controls that do not require identity collection, publish a threat-model update process, and run interoperability tests against multiple Nostr relays.

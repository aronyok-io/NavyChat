# Protocol decisions

This document is a design target, not an implemented wire protocol. It makes the privacy properties of each Relayline mode explicit before implementation begins.

## The transport-independent envelope

Every encrypted message is wrapped in a small signed, opaque transport envelope:

```text
version | envelope-id | expiry | remaining-hops | audience | encrypted-payload
```

Forwarders only need the envelope ID, expiry, hop budget, and audience routing hint. They must reject unknown versions, expired packets, packets over the size limit, and IDs in their replay cache. They must not log or parse message plaintext.

The core will define canonical byte encoding before Bluetooth and Nostr adapters are allowed to interoperate. JSON is useful for debugging but is not a safe canonical signing format by itself.

## Nearby mesh

BLE advertising discovers peers; a negotiated GATT/L2CAP connection transfers bounded envelopes. A node uses a random rotating radio identifier, not its Bluetooth MAC address or Nostr public key, while advertising. It forwards only under the user’s battery, data, and room policy.

The first usable release should prefer reliable, low-rate text delivery over claims of a universal mesh. Radio range, OS background limits, Bluetooth implementation, and crowd density materially affect delivery. The UI should say **queued**, **forwarded**, or **acknowledged by recipient**—never just “sent.”

## Global Nostr delivery

For private one-to-one and small-group messages, Relayline targets NIP-17 message semantics, NIP-44 v2 payload encryption, and NIP-59 gift wraps. NIP-17 is still marked draft, so protocol support must be feature-negotiated and isolated behind an adapter. NIP-04 must not be used for new private messaging.

Relay selection is local configuration. The app needs relay health, reconnect backoff, publish receipts, subscription limits, and no automatic upload of an address book. A relay receives network metadata such as the client IP unless the user independently chooses an appropriate network privacy layer.

## Place rooms are two distinct products

### Open place room

An open place room is suitable for event notices, public conversations, or local announcements. It publishes a coarse location tag such as `geo:dr5ru` alongside a public event. It is discoverable and not end-to-end private. The app must use an unmistakable **OPEN** badge and avoid precisely locating a user.

### Private place circle

A private place circle has a random room ID and a group encryption key/epoch. The approximate location is a local UI filter, not a secret or a public Nostr routing tag. A creator distributes an invite over a verified direct channel or QR code. Membership changes rotate the epoch key. Long-lived or large circles should ultimately use a reviewed group messaging protocol rather than a shared static secret.

## Delivery and acknowledgement

`queued` means stored locally. `relayed` means accepted by one transport peer or relay. `published` means a Nostr relay accepted the outer event. `acknowledged` means an authenticated recipient acknowledgement was received. It does not promise that a person read it.

## Inputs that need an explicit product decision

1. Maximum group size and whether it warrants MLS/another reviewed group protocol.
2. Message retention and expiry defaults, including relay deletion requests.
3. Whether open place rooms are included in v1 at all.
4. Abuse reporting/blocking that works without a central account or phone number.
5. Availability of secure key backup versus a strict no-recovery identity model.

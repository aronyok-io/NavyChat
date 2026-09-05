# Relayline — improved prototype

## Now included

- A shared Swift core with validated geohashes, packet expiration, mesh hop limits, duplicate suppression, transport selection, delivery-state transitions, and a richer IRC command parser.
- A blue SwiftUI desktop experience with room rail, conversations, message path/details inspector, location-room flow, command hints, and explicit mesh/Nostr status states.
- An Android Compose starter with the same IRC-inspired visual language, Bluetooth permission states, nearby discovery, and lifecycle cleanup.
- Honest transport boundaries: the Android radio sends only a rotating anonymous discovery marker. Actual encrypted mesh packet transfer remains intentionally disabled until its authenticated peer bearer is implemented and independently reviewed.
- Clear product language separating open geohash rooms from invite-only private place circles.

## Try it

1. With a Swift toolchain installed, run `swift test` or `swift run RelaylineCLI` at the repository root.
2. On macOS 14+, open `DesktopDemo` as a Swift package in Xcode to explore the visual prototype.
3. Open `android` in Android Studio with Android SDK 35 to run the Compose starter on an Android device or emulator.

## Important next build milestones

1. Implement a reviewed, bounded BLE peer-transfer bearer for opaque encrypted envelopes.
2. Integrate audited key storage and a real encrypted-message protocol; do not write custom cryptography.
3. Add a Nostr adapter with NIP-44 v2/NIP-59 and feature-negotiated NIP-17 support.
4. Build the Windows and Linux native host shells on top of the shared policy/core layer.
5. Commission a security review before any real-world emergency or safety use.

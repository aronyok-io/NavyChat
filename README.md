# Relayline

Relayline is a private, accountless chat system designed to work in two modes:

- **Nearby mode:** Bluetooth Low Energy peers form a store-and-forward mesh for people in the same physical area.
- **Global mode:** Nostr relays carry encrypted direct messages and opt-in geohash room events between distant peers.

It intentionally has an IRC-like interaction model (`/join`, `/msg`, `/me`, `/who`) while using public keys instead of usernames, phone numbers, or central accounts.

## Important platform decision

The shared domain and protocol code is Swift. Android cannot depend on SwiftUI or Apple Bluetooth APIs, and Windows/Linux cannot run SwiftUI, so each platform needs a thin native host:

| Platform | Native shell | Nearby transport |
| --- | --- | --- |
| Android | Kotlin + Jetpack Compose | Android BLE/nearby APIs |
| Windows | WinUI 3 (or a Swift-compatible desktop shell) | Windows Bluetooth LE |
| Linux | GTK/Libadwaita (or SwiftGtk) | BlueZ |

The app behaviour, event formats, identity, routing rules, and encryption boundary belong in `MeshChatCore`. This prevents three separate implementations of the safety-critical logic.

## What is in this improved starter

- `Sources/MeshChatCore`: portable Swift models for IRC commands, geohash rooms, message envelopes, bounded mesh forwarding, expiry, and delivery state.
- `Sources/RelaylineCLI`: a simple local command console for trying the interaction model on macOS/Linux/Windows.
- `DesktopDemo/`: a blue SwiftUI visual prototype for the desktop conversation experience.
- `android/`: Kotlin/Compose starter interfaces and screens; the bridge deliberately does not invent cryptography.
- `docs/`: product, security, protocol, and blue visual-system decisions.

## Run the CLI

Install a current Swift toolchain, then run:

```sh
swift run RelaylineCLI
```

Example:

```text
/join geo:u4pruy
/msg npub1… hello from the mesh
/me is testing the radio
```

## Explore the interfaces

- **Desktop visual prototype:** open [DesktopDemo](DesktopDemo/README.md) with Xcode on macOS 14+, or run `swift run` from that directory. It is a polished local-only SwiftUI simulation—its status controls model states and do not connect to a network.
- **Android starter:** open the `android/` directory in Android Studio with an Android 35 SDK installed. It contains the blue Compose interface, command handling, permission flow, and privacy-preserving BLE presence discovery. It deliberately does **not** transfer chat packets yet.

Windows and Linux still need their native shells. The shared Swift core is intentionally independent of UI and radio APIs so those hosts do not need to reimplement packet policy, routing, or command handling.

## Security boundary

This repository does **not** claim that the scaffold already provides end-to-end encryption. Before any real release, use audited implementations of:

- Nostr NIP-44 v2 for encrypted Nostr payloads, with NIP-17 gift wrapping where metadata protection is needed.
- A reviewed authenticated-encryption scheme for offline packets, with per-message nonce handling, forward secrecy, replay resistance, and key verification.

Read [the security design](docs/security.md) before implementing transports or shipping a test build.

## A necessary product distinction

“Location based” and “private” are compatible only when room membership is deliberately established. A country-wide room that anyone can discover from a public geohash cannot also hide its membership or content from anyone who subscribes.

Relayline therefore supports two clearly labelled room modes:

- **Open place rooms** are discoverable Nostr conversations. Their coarse geohash is public metadata and users should consider their messages public.
- **Private place circles** are invite-only encrypted groups associated with an approximate area. Entry uses an in-person QR invite or an encrypted direct invite; the geohash is never a room secret.

This choice avoids presenting false privacy. See [the protocol decisions](docs/protocol.md).

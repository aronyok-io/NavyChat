# Relayline desktop demo

A dependency-free macOS SwiftUI visual prototype for Relayline: an encrypted, IRC-inspired chat client that makes nearby Bluetooth mesh and global Nostr relay state visible without overstating delivery guarantees.

## Run it

Open this folder as a Swift package in Xcode on macOS 14 or newer, select the `RelaylineDesktopDemo` executable, and run it. You can also run `swift run` from this directory with a current macOS Swift toolchain.

The demo is intentionally local-only. The composer, room switcher, slash-command hints, status toggles, and room inspector are interactive UI states; none connect to Bluetooth or Nostr yet.

## What to look for

- Deep-navy, signal-blue visual system based on the project palette.
- Compact IRC-style room rail with location precision and transport badges.
- Honest states such as `queued`, `relayed`, and `delivered` rather than a generic sent checkmark.
- A visible privacy boundary: local identity, room key verification, and scoped location rooms.
- Desktop details that map cleanly to a future native host: inspector, transport cards, keyboard-focused composer, and command suggestions.

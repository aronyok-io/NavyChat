# Product and UI direction

## The experience

The main screen feels like a calm, old-school IRC client—not a social feed. A compact status line says `MESH ONLINE · 6 nearby hops` or `RELAY ONLINE · 3 relays`; it never implies delivery certainty. A left rail contains conversations and joined rooms, while the main pane holds the transcript and a single command-aware composer.

The first screen explains the two networks in plain language: **Nearby** reaches people through Bluetooth, even without internet. **Global** reaches encrypted contacts through Nostr relays. The user chooses what to enable, and either can be turned off at any time.

## Blue visual system

| Role | Value | Use |
| --- | --- | --- |
| Night | `#081526` | App background |
| Surface | `#10243D` | Panels and composer |
| Border | `#244665` | Quiet dividers |
| Signal | `#38BDF8` | Active channel, links, focus |
| Bright | `#7DD3FC` | Primary actions, sent-message accent |
| Ink | `#E6F4FF` | Main text |
| Muted | `#91B4CE` | Timestamps and secondary status |
| Alert | `#FBBF24` | Transport degradation—not danger by default |

Use 12px corner radii, generous 16–20px padding, a modern system sans face for UI, and a monospace face only for commands, fingerprints, and relay status. Avoid bright blue full-page fills; blue is most effective as a signal against a deep navy field.

## Core flows

1. **Create identity:** generate keys locally, show a short fingerprint, offer QR export. No sign-up screen.
2. **Start nearby:** ask for Bluetooth permission only at this moment; display radio/battery impact and current transport state.
3. **Join location room:** choose precision from Block, Neighborhood, City, Region, Country; show the geohash and privacy effect before joining.
4. **Send:** enter normal text to the selected room, or use `/msg <npub> <text>` for a direct message. Messages show `queued`, `relayed`, or `delivered` only when the protocol can honestly establish that state.

## Commands

`/join <geohash>` · `/leave [room]` · `/msg <npub> <text>` · `/me <action>` · `/who [room]` · `/verify <npub>` · `/relay add <url>` · `/offline` · `/help`

`/who` must communicate available, consented presence only; it cannot silently scan or reveal nearby devices.

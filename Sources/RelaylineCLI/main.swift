import Foundation
import MeshChatCore

let demoIdentity = PeerID("npub-demo-7a3d")

print("Relayline — local console")
print("Identity: \(demoIdentity)")
print("Use /help. This console never sends a message to a network.")

while let line = readLine() {
    switch IRCCommand.parse(line) {
    case .join(let room): print("Joined #\(room). Room membership is opt-in.")
    case .leave(let room):
        let roomLabel = room.map { "#" + $0 } ?? "the current room"
        print("Left \(roomLabel).")
    case .message(let target, let body): print("Queued encrypted message to \(target): \(body)")
    case .action(let action): print("* you \(action)")
    case .who(let room):
        let roomSuffix = room.map { " for #" + $0 } ?? ""
        print("Presence is private by default. No peer list exposed\(roomSuffix).")
    case .verify(let peer): print("Open QR/fingerprint verification for \(peer).")
    case .relayAdd(let url): print("Saved relay \(url.absoluteString) locally. It has not been contacted yet.")
    case .offline: print("Global relay delivery is paused. Nearby mesh settings are unchanged.")
    case .help: print("/join <geohash>  /leave [room]  /msg <npub|#room> <text>  /me <action>  /who [room]  /verify <npub>  /relay add <wss-url>  /offline")
    case .unknown: print("Unknown command. Try /help.")
    }
}

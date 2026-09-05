import Foundation

// MARK: - Identity and room addressing

/// An application-level public identity. Relayline deliberately does not tie this
/// value to a phone number, account, or contact-book entry.
public struct PeerID: Hashable, Codable, Sendable, CustomStringConvertible {
    public static let maximumLength = 128

    public let value: String

    /// Kept non-failable so decoded or externally supplied identifiers can be
    /// represented and then rejected at a trust boundary with `isValid`.
    public init(_ value: String) {
        self.value = value
    }

    /// Creates a normalized peer identifier suitable for outgoing messages.
    public init?(validating rawValue: String) {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.utf8.count <= Self.maximumLength,
              !candidate.contains(where: { $0.isWhitespace }),
              !candidate.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F })
        else {
            return nil
        }
        self.value = candidate
    }

    public var isValid: Bool {
        PeerID(validating: value) != nil
    }

    public var normalized: PeerID? {
        PeerID(validating: value)
    }

    public var description: String {
        value
    }
}

/// A normalized geohash. It is intentionally capped at twelve characters: that
/// is the conventional maximum precision and keeps room names bounded on mesh
/// advertisements and relay tags.
public struct Geohash: Hashable, Codable, Sendable, CustomStringConvertible {
    public static let minimumPrecision = 1
    public static let maximumPrecision = 12
    public static let alphabet = "0123456789bcdefghjkmnpqrstuvwxyz"

    public let value: String

    public init?(_ rawValue: String) {
        let candidate = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard (Self.minimumPrecision...Self.maximumPrecision).contains(candidate.count),
              candidate.allSatisfy({ Self.alphabet.contains($0) })
        else {
            return nil
        }

        self.value = candidate
    }

    public static func isValid(_ rawValue: String) -> Bool {
        Geohash(rawValue) != nil
    }

    /// The next larger geographic room, if one exists.
    public var parent: Geohash? {
        guard value.count > Self.minimumPrecision else { return nil }
        return Geohash(String(value.dropLast()))
    }

    /// Returns true when `other` is this room or a more precise room inside it.
    public func contains(_ other: Geohash) -> Bool {
        other.value.hasPrefix(value)
    }

    public var description: String {
        value
    }
}

public enum RoomValidationError: Error, Equatable, Sendable {
    case invalidPeerID
    case invalidGeohash
}

public enum Room: Hashable, Codable, Sendable {
    case direct(PeerID)
    /// Geohash precision expresses room size. Use `Room.geohashRoom(_:)` or
    /// `Room.parse(_:)` for untrusted input before constructing an envelope.
    case geohash(String)

    /// Parses `#u4pruy`, `u4pruy`, or `@peer-id`. Bare values are interpreted as
    /// geohashes so a peer must be explicit with `@` in user-facing input.
    public static func parse(_ rawValue: String) -> Room? {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        if candidate.first == "@" {
            return directRoom(String(candidate.dropFirst()))
        }
        return geohashRoom(candidate)
    }

    public static func geohashRoom(_ rawValue: String) -> Room? {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = candidate.first == "#" ? String(candidate.dropFirst()) : candidate
        guard let geohash = Geohash(withoutPrefix) else { return nil }
        return .geohash(geohash.value)
    }

    public static func directRoom(_ rawValue: String) -> Room? {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = candidate.first == "@" ? String(candidate.dropFirst()) : candidate
        guard let peer = PeerID(validating: withoutPrefix) else { return nil }
        return .direct(peer)
    }

    /// A normalized room, or `nil` if this value was constructed from untrusted
    /// data without using one of the parsing helpers.
    public var normalized: Room? {
        switch self {
        case .direct(let peer):
            return peer.normalized.map { .direct($0) }
        case .geohash(let value):
            return Room.geohashRoom(value)
        }
    }

    public var validationError: RoomValidationError? {
        switch self {
        case .direct(let peer):
            return peer.isValid ? nil : .invalidPeerID
        case .geohash(let value):
            return Geohash(value) == nil ? .invalidGeohash : nil
        }
    }

    /// A presentation-only address. Do not use it as encrypted-message content.
    public var displayName: String {
        switch self {
        case .direct(let peer):
            return "@\(peer.value)"
        case .geohash(let value):
            return "#\(value.lowercased())"
        }
    }
}

/// Resolves an IRC `/msg` target without making a naked string ambiguous between
/// a public identity and a geographic room. Geographic targets use `#`.
public enum MessageTarget: Hashable, Codable, Sendable {
    case peer(PeerID)
    case room(Room)

    public static func parse(_ rawValue: String) -> MessageTarget? {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        if candidate.first == "#" {
            return Room.geohashRoom(candidate).map { .room($0) }
        }
        let withoutPrefix = candidate.first == "@" ? String(candidate.dropFirst()) : candidate
        return PeerID(validating: withoutPrefix).map { .peer($0) }
    }

    public var ircTarget: String {
        switch self {
        case .peer(let peer):
            return peer.value
        case .room(let room):
            return room.displayName
        }
    }
}

// MARK: - Message envelopes

public struct MessageValidationPolicy: Hashable, Sendable {
    public static let standard = MessageValidationPolicy()

    public let maximumCiphertextBytes: Int
    public let maximumAge: TimeInterval
    public let maximumTimeToLive: TimeInterval
    public let maximumFutureClockSkew: TimeInterval
    public let maximumHops: UInt8

    public init(
        maximumCiphertextBytes: Int = 64 * 1024,
        maximumAge: TimeInterval = 7 * 24 * 60 * 60,
        maximumTimeToLive: TimeInterval = MessageEnvelope.defaultTimeToLive,
        maximumFutureClockSkew: TimeInterval = 5 * 60,
        maximumHops: UInt8 = 12
    ) {
        self.maximumCiphertextBytes = max(0, maximumCiphertextBytes)
        self.maximumAge = Self.nonNegativeFinite(maximumAge)
        self.maximumTimeToLive = Self.nonNegativeFinite(maximumTimeToLive)
        self.maximumFutureClockSkew = Self.nonNegativeFinite(maximumFutureClockSkew)
        self.maximumHops = maximumHops
    }

    private static func nonNegativeFinite(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite, value >= 0 else { return 0 }
        return value
    }
}

public enum MessageValidationError: Error, Equatable, Sendable {
    case invalidSender
    case invalidRoom(RoomValidationError)
    case emptyCiphertext
    case ciphertextTooLarge(actual: Int, maximum: Int)
    case hopLimitExceeded(actual: UInt8, maximum: UInt8)
    case invalidExpiry
    case lifetimeTooLong
    case createdAtTooFarInFuture
    case expired
    case tooOld
}

public struct MessageEnvelope: Codable, Hashable, Sendable {
    public static let defaultTimeToLive: TimeInterval = 24 * 60 * 60

    public let id: UUID
    public let sender: PeerID
    public let room: Room
    /// Ciphertext must include its AEAD authentication tag. The core never sees
    /// plaintext and therefore never serializes message text into mesh metadata.
    public let ciphertext: Data
    public let createdAt: Date
    public let expiresAt: Date
    /// A hard cap prevents an offline packet from flooding the mesh forever.
    public let remainingHops: UInt8

    public init(
        id: UUID = UUID(),
        sender: PeerID,
        room: Room,
        ciphertext: Data,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        remainingHops: UInt8 = 6
    ) {
        self.id = id
        self.sender = sender
        self.room = room
        self.ciphertext = ciphertext
        self.createdAt = createdAt
        self.expiresAt = expiresAt ?? createdAt.addingTimeInterval(Self.defaultTimeToLive)
        self.remainingHops = remainingHops
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        date >= expiresAt
    }

    /// Returns the first validation issue so callers can reject malformed packets
    /// before decryption, storage, relay publishing, or Bluetooth forwarding.
    public func validationError(
        at date: Date = Date(),
        policy: MessageValidationPolicy = .standard
    ) -> MessageValidationError? {
        guard sender.isValid else { return .invalidSender }
        if let roomError = room.validationError {
            return .invalidRoom(roomError)
        }
        guard !ciphertext.isEmpty else { return .emptyCiphertext }
        guard ciphertext.count <= policy.maximumCiphertextBytes else {
            return .ciphertextTooLarge(actual: ciphertext.count, maximum: policy.maximumCiphertextBytes)
        }
        guard remainingHops <= policy.maximumHops else {
            return .hopLimitExceeded(actual: remainingHops, maximum: policy.maximumHops)
        }
        guard expiresAt > createdAt else { return .invalidExpiry }
        guard expiresAt.timeIntervalSince(createdAt) <= policy.maximumTimeToLive else {
            return .lifetimeTooLong
        }
        guard createdAt.timeIntervalSince(date) <= policy.maximumFutureClockSkew else {
            return .createdAtTooFarInFuture
        }
        guard !isExpired(at: date) else { return .expired }
        guard date.timeIntervalSince(createdAt) <= policy.maximumAge else { return .tooOld }
        return nil
    }

    public func isValid(
        at date: Date = Date(),
        policy: MessageValidationPolicy = .standard
    ) -> Bool {
        validationError(at: date, policy: policy) == nil
    }

    /// Produces the next mesh packet only while it remains valid. A receiving
    /// transport should check its duplicate cache before broadcasting this value.
    public func forwarded(
        at date: Date = Date(),
        policy: MessageValidationPolicy = .standard
    ) -> MessageEnvelope? {
        guard remainingHops > 0, validationError(at: date, policy: policy) == nil else {
            return nil
        }
        return MessageEnvelope(
            id: id,
            sender: sender,
            room: room,
            ciphertext: ciphertext,
            createdAt: createdAt,
            expiresAt: expiresAt,
            remainingHops: remainingHops - 1
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sender
        case room
        case ciphertext
        case createdAt
        case expiresAt
        case remainingHops
    }

    /// Missing expirations from early prerelease packets are upgraded to the
    /// conservative default TTL rather than becoming immortal after decoding.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.sender = try container.decode(PeerID.self, forKey: .sender)
        self.room = try container.decode(Room.self, forKey: .room)
        self.ciphertext = try container.decode(Data.self, forKey: .ciphertext)
        self.createdAt = createdAt
        self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? createdAt.addingTimeInterval(Self.defaultTimeToLive)
        self.remainingHops = try container.decode(UInt8.self, forKey: .remainingHops)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sender, forKey: .sender)
        try container.encode(room, forKey: .room)
        try container.encode(ciphertext, forKey: .ciphertext)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(remainingHops, forKey: .remainingHops)
    }
}

/// A small bounded cache used by transports to suppress duplicate mesh packets.
/// It intentionally stores message IDs only; no plaintext or room history is
/// retained here.
public actor SeenMessageCache {
    private var seen: Set<UUID> = []
    private var order: [UUID] = []
    private let capacity: Int

    public init(capacity: Int = 2_000) {
        self.capacity = max(0, capacity)
    }

    /// Returns true only once per message ID. Transports call this before
    /// forwarding. A zero-capacity cache behaves as an explicit no-cache mode.
    public func accept(_ id: UUID) -> Bool {
        guard capacity > 0 else { return true }
        guard seen.insert(id).inserted else { return false }

        order.append(id)
        if order.count > capacity {
            seen.remove(order.removeFirst())
        }
        return true
    }

    /// Validates an untrusted envelope before putting its ID into the duplicate
    /// cache, so malformed traffic cannot poison the cache.
    public func accept(
        _ envelope: MessageEnvelope,
        at date: Date = Date(),
        policy: MessageValidationPolicy = .standard
    ) -> Bool {
        guard envelope.isValid(at: date, policy: policy) else { return false }
        return accept(envelope.id)
    }

    public var count: Int {
        seen.count
    }

    public func removeAll() {
        seen.removeAll(keepingCapacity: false)
        order.removeAll(keepingCapacity: false)
    }
}

// MARK: - Transport routing and delivery

public enum TransportKind: String, Codable, CaseIterable, Sendable {
    case bluetoothMesh
    case nostr
}

public struct TransportAvailability: Hashable, Codable, Sendable {
    public let bluetoothMeshAvailable: Bool
    public let nostrAvailable: Bool

    public init(bluetoothMeshAvailable: Bool, nostrAvailable: Bool) {
        self.bluetoothMeshAvailable = bluetoothMeshAvailable
        self.nostrAvailable = nostrAvailable
    }

    public func isAvailable(_ transport: TransportKind) -> Bool {
        switch transport {
        case .bluetoothMesh:
            return bluetoothMeshAvailable
        case .nostr:
            return nostrAvailable
        }
    }
}

public enum TransportPreference: String, Codable, CaseIterable, Sendable {
    /// Reach nearby peers and the global relay network at once when both work.
    case automatic
    /// Prefer local mesh, and attempt Nostr only after local delivery cannot work.
    case offlineFirst
    case localOnly
    case internetOnly
}

public enum TransportDispatch: String, Codable, Sendable {
    case sequential
    case parallel
}

public struct TransportPlan: Hashable, Codable, Sendable {
    public let primary: TransportKind?
    public let fallbacks: [TransportKind]
    public let dispatch: TransportDispatch

    public init(
        primary: TransportKind?,
        fallbacks: [TransportKind] = [],
        dispatch: TransportDispatch = .sequential
    ) {
        guard let primary else {
            self.primary = nil
            self.fallbacks = []
            self.dispatch = .sequential
            return
        }

        var uniqueFallbacks: [TransportKind] = []
        for transport in fallbacks where transport != primary && !uniqueFallbacks.contains(transport) {
            uniqueFallbacks.append(transport)
        }
        self.primary = primary
        self.fallbacks = uniqueFallbacks
        self.dispatch = dispatch
    }

    public static let unavailable = TransportPlan(primary: nil)

    public var orderedTransports: [TransportKind] {
        guard let primary else { return [] }
        return [primary] + fallbacks
    }

    public var isAvailable: Bool {
        primary != nil
    }
}

public enum TransportPlanningOutcome: Equatable, Sendable {
    case ready(TransportPlan)
    case invalidMessage(MessageValidationError)
}

public enum TransportSelector {
    public static func select(
        preference: TransportPreference = .automatic,
        availability: TransportAvailability
    ) -> TransportPlan {
        let mesh = availability.bluetoothMeshAvailable
        let nostr = availability.nostrAvailable

        switch preference {
        case .automatic:
            switch (mesh, nostr) {
            case (true, true):
                return TransportPlan(primary: .bluetoothMesh, fallbacks: [.nostr], dispatch: .parallel)
            case (true, false):
                return TransportPlan(primary: .bluetoothMesh)
            case (false, true):
                return TransportPlan(primary: .nostr)
            case (false, false):
                return .unavailable
            }

        case .offlineFirst:
            if mesh {
                return TransportPlan(
                    primary: .bluetoothMesh,
                    fallbacks: nostr ? [.nostr] : [],
                    dispatch: .sequential
                )
            }
            return nostr ? TransportPlan(primary: .nostr) : .unavailable

        case .localOnly:
            return mesh ? TransportPlan(primary: .bluetoothMesh) : .unavailable

        case .internetOnly:
            return nostr ? TransportPlan(primary: .nostr) : .unavailable
        }
    }

    /// Avoids selecting a transport for packets that should be dropped locally.
    public static func plan(
        for envelope: MessageEnvelope,
        preference: TransportPreference = .automatic,
        availability: TransportAvailability,
        at date: Date = Date(),
        validationPolicy: MessageValidationPolicy = .standard
    ) -> TransportPlanningOutcome {
        if let error = envelope.validationError(at: date, policy: validationPolicy) {
            return .invalidMessage(error)
        }
        return .ready(select(preference: preference, availability: availability))
    }
}

public enum DeliveryState: String, Codable, CaseIterable, Sendable {
    case queued
    case sending
    case sent
    case relayed
    case delivered
    case failed
    case expired

    /// Delivered and expired records cannot safely advance. A failed record is
    /// deliberately retryable by moving it back to `queued`.
    public var isTerminal: Bool {
        self == .delivered || self == .expired
    }

    public var canRetry: Bool {
        self == .failed
    }

    public func canTransition(to nextState: DeliveryState) -> Bool {
        if nextState == .expired {
            return !isTerminal
        }

        switch (self, nextState) {
        case (.queued, .sending),
             (.queued, .failed),
             (.sending, .sent),
             (.sending, .failed),
             (.sent, .relayed),
             (.sent, .delivered),
             (.sent, .failed),
             (.relayed, .relayed),
             (.relayed, .delivered),
             (.relayed, .failed),
             (.failed, .queued):
            return true
        default:
            return false
        }
    }
}

public enum DeliveryTransitionError: Error, Equatable, Sendable {
    case invalidTransition(from: DeliveryState, to: DeliveryState)
    case messageExpired
}

public enum DeliveryFailureReason: String, Codable, Sendable {
    case noAvailableTransport
    case transportRejected
    case timedOut
    case encryptionFailed
    case unknown
}

/// Local delivery metadata. It is intentionally separate from `MessageEnvelope`
/// so transport state never changes the signed/encrypted message representation.
public struct MessageDelivery: Hashable, Codable, Sendable {
    public let messageID: UUID
    public private(set) var state: DeliveryState
    public private(set) var attemptedTransports: [TransportKind]
    public private(set) var failureReason: DeliveryFailureReason?
    public private(set) var updatedAt: Date

    public init(
        messageID: UUID,
        state: DeliveryState = .queued,
        attemptedTransports: [TransportKind] = [],
        updatedAt: Date = Date()
    ) {
        self.messageID = messageID
        self.state = state
        self.attemptedTransports = Self.unique(attemptedTransports)
        self.failureReason = nil
        self.updatedAt = updatedAt
    }

    /// Starts a transmission attempt. Retrying after `failed` requires an
    /// explicit transition back to `queued`, preventing accidental retries of a
    /// delivered message.
    public mutating func beginAttempt(
        on transport: TransportKind,
        at date: Date = Date(),
        expiresAt: Date? = nil
    ) throws {
        try transition(to: .sending, at: date, expiresAt: expiresAt)
        if !attemptedTransports.contains(transport) {
            attemptedTransports.append(transport)
        }
    }

    public mutating func fail(
        _ reason: DeliveryFailureReason,
        at date: Date = Date(),
        expiresAt: Date? = nil
    ) throws {
        try transition(to: .failed, at: date, expiresAt: expiresAt)
        failureReason = reason
    }

    public mutating func transition(
        to nextState: DeliveryState,
        at date: Date = Date(),
        expiresAt: Date? = nil
    ) throws {
        if let expiresAt, date >= expiresAt, nextState != .expired {
            state = .expired
            updatedAt = date
            throw DeliveryTransitionError.messageExpired
        }

        guard state.canTransition(to: nextState) else {
            throw DeliveryTransitionError.invalidTransition(from: state, to: nextState)
        }

        state = nextState
        updatedAt = date
        if nextState != .failed {
            failureReason = nil
        }
    }

    private static func unique(_ transports: [TransportKind]) -> [TransportKind] {
        var result: [TransportKind] = []
        for transport in transports where !result.contains(transport) {
            result.append(transport)
        }
        return result
    }
}

// MARK: - IRC-style command parsing

public enum IRCCommand: Equatable, Sendable {
    case join(String)
    case leave(String?)
    case message(target: String, body: String)
    case action(String)
    case who(String?)
    case verify(PeerID)
    case relayAdd(URL)
    case offline
    case help
    case unknown(String)

    /// Compatibility entry point for the command set used by the initial CLI.
    /// Use `IRCCommandParser.parse(_:)` when the UI needs a specific validation
    /// error instead of the legacy `.unknown` fallback.
    public static func parse(_ input: String) -> IRCCommand {
        switch IRCCommandParser.parse(input) {
        case .command(let command):
            return command
        case .plainText, .invalid:
            return .unknown(input)
        }
    }

    public var messageTarget: MessageTarget? {
        guard case .message(let target, _) = self else { return nil }
        return MessageTarget.parse(target)
    }
}

public enum IRCCommandParseError: Error, Equatable, Sendable {
    case emptyInput
    case unsupportedCommand(String)
    case missingArgument(command: String)
    case invalidRoom(String)
    case invalidTarget(String)
    case invalidRelayURL(String)
    case emptyBody(command: String)
    case unexpectedArguments(command: String)
}

public enum IRCCommandParseResult: Equatable, Sendable {
    case command(IRCCommand)
    case plainText(String)
    case invalid(IRCCommandParseError)
}

public enum IRCCommandParser {
    public static func parse(_ rawInput: String) -> IRCCommandParseResult {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .invalid(.emptyInput) }
        guard input.first == "/" else { return .plainText(rawInput) }

        let (rawName, arguments) = splitCommand(input)
        let name = rawName.lowercased()
        guard !name.isEmpty else { return .invalid(.unsupportedCommand("/")) }

        switch name {
        case "join":
            guard !arguments.isEmpty else { return .invalid(.missingArgument(command: "/join")) }
            guard let rawRoom = singleArgument(arguments), let room = Room.geohashRoom(rawRoom) else {
                return .invalid(.invalidRoom(arguments))
            }
            guard case .geohash(let geohash) = room else {
                return .invalid(.invalidRoom(arguments))
            }
            return .command(.join(geohash))

        case "leave":
            guard !arguments.isEmpty else { return .command(.leave(nil)) }
            guard let rawRoom = singleArgument(arguments), let room = Room.geohashRoom(rawRoom) else {
                return .invalid(.invalidRoom(arguments))
            }
            guard case .geohash(let geohash) = room else {
                return .invalid(.invalidRoom(arguments))
            }
            return .command(.leave(geohash))

        case "msg":
            return parseMessage(arguments)

        case "me":
            guard !arguments.isEmpty else { return .invalid(.emptyBody(command: "/me")) }
            return .command(.action(arguments))

        case "who":
            guard !arguments.isEmpty else { return .command(.who(nil)) }
            guard let rawRoom = singleArgument(arguments), let room = Room.geohashRoom(rawRoom) else {
                return .invalid(.invalidRoom(arguments))
            }
            guard case .geohash(let geohash) = room else {
                return .invalid(.invalidRoom(arguments))
            }
            return .command(.who(geohash))

        case "verify":
            guard let candidate = singleArgument(arguments) else {
                return .invalid(arguments.isEmpty ? .missingArgument(command: "/verify") : .invalidTarget(arguments))
            }
            guard let peer = PeerID(validating: candidate) else {
                return .invalid(.invalidTarget(candidate))
            }
            return .command(.verify(peer))

        case "relay":
            return parseRelay(arguments)

        case "offline":
            guard arguments.isEmpty else { return .invalid(.unexpectedArguments(command: "/offline")) }
            return .command(.offline)

        case "help":
            guard arguments.isEmpty else { return .invalid(.unexpectedArguments(command: "/help")) }
            return .command(.help)

        default:
            return .invalid(.unsupportedCommand("/\(rawName)"))
        }
    }

    private static func parseMessage(_ arguments: String) -> IRCCommandParseResult {
        guard !arguments.isEmpty else { return .invalid(.missingArgument(command: "/msg")) }

        let parts = arguments.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )
        guard let rawTarget = parts.first else {
            return .invalid(.missingArgument(command: "/msg"))
        }
        guard parts.count == 2 else {
            return .invalid(.emptyBody(command: "/msg"))
        }

        let targetString = String(rawTarget)
        guard let target = MessageTarget.parse(targetString) else {
            return .invalid(.invalidTarget(targetString))
        }
        let body = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .invalid(.emptyBody(command: "/msg")) }
        return .command(.message(target: target.ircTarget, body: body))
    }

    private static func parseRelay(_ arguments: String) -> IRCCommandParseResult {
        let parts = arguments.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: { $0.isWhitespace }
        )
        guard let subcommand = parts.first?.lowercased() else {
            return .invalid(.missingArgument(command: "/relay"))
        }
        guard subcommand == "add" else {
            return .invalid(.unsupportedCommand("/relay \(subcommand)"))
        }
        guard parts.count == 2 else {
            return .invalid(.missingArgument(command: "/relay add"))
        }
        let rawURL = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: rawURL),
              url.scheme?.lowercased() == "wss",
              url.host != nil,
              url.user == nil,
              url.password == nil
        else {
            return .invalid(.invalidRelayURL(rawURL))
        }
        return .command(.relayAdd(url))
    }

    private static func splitCommand(_ input: String) -> (name: String, arguments: String) {
        let body = input.dropFirst()
        guard let separator = body.firstIndex(where: { $0.isWhitespace }) else {
            return (String(body), "")
        }

        let name = String(body[..<separator])
        let argumentStart = body.index(after: separator)
        let arguments = String(body[argumentStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (name, arguments)
    }

    private static func singleArgument(_ arguments: String) -> String? {
        let parts = arguments.split(whereSeparator: { $0.isWhitespace })
        guard parts.count == 1 else { return nil }
        return String(parts[0])
    }
}

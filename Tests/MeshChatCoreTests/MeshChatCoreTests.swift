import XCTest
@testable import MeshChatCore

final class MeshChatCoreTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_000_000)

    func testGeohashNormalizesAndRejectsInvalidCharacters() {
        XCTAssertEqual(Geohash(" U4PRUY ")?.value, "u4pruy")
        XCTAssertNil(Geohash("u4pr!"))
        XCTAssertNil(Geohash("u4pr i"))
        XCTAssertNil(Geohash(String(repeating: "u", count: 13)))
    }

    func testGeohashHierarchyAndRoomParsing() {
        let city = Geohash("u4pr")!
        let block = Geohash("u4pruyd")!
        XCTAssertTrue(city.contains(block))
        XCTAssertEqual(block.parent?.value, "u4pruy")

        XCTAssertEqual(Room.parse(" #U4PRUY "), .geohash("u4pruy"))
        XCTAssertEqual(Room.parse("@npub1alice"), .direct(PeerID("npub1alice")))
        XCTAssertNil(Room.parse("not-a-geohash"))
        XCTAssertEqual(Room.geohash("bad!").validationError, .invalidGeohash)
    }

    func testMessageTargetRequiresHashPrefixForRooms() {
        XCTAssertEqual(MessageTarget.parse("#U4PRUY"), .room(.geohash("u4pruy")))
        XCTAssertEqual(MessageTarget.parse("@npub1alice"), .peer(PeerID("npub1alice")))
        XCTAssertEqual(MessageTarget.parse("npub1alice")?.ircTarget, "npub1alice")
        XCTAssertNil(MessageTarget.parse("#not-a-geohash"))
    }

    func testMessageCanOnlyBeForwardedForItsHopBudget() {
        let original = makeEnvelope(remainingHops: 1)
        let forwarded = original.forwarded(at: referenceDate)
        XCTAssertEqual(forwarded?.remainingHops, 0)
        XCTAssertNil(forwarded?.forwarded(at: referenceDate))
    }

    func testExpiredAndOversizedMessagesAreRejectedBeforeForwarding() {
        let expired = makeEnvelope(
            createdAt: referenceDate.addingTimeInterval(-20),
            expiresAt: referenceDate.addingTimeInterval(-1)
        )
        XCTAssertEqual(expired.validationError(at: referenceDate), .expired)
        XCTAssertNil(expired.forwarded(at: referenceDate))

        let oversized = MessageEnvelope(
            sender: PeerID("alice"),
            room: .geohash("u4pr"),
            ciphertext: Data(repeating: 1, count: 5),
            createdAt: referenceDate,
            expiresAt: referenceDate.addingTimeInterval(60)
        )
        let policy = MessageValidationPolicy(
            maximumCiphertextBytes: 4,
            maximumAge: 60,
            maximumTimeToLive: 60,
            maximumFutureClockSkew: 0,
            maximumHops: 6
        )
        XCTAssertEqual(
            oversized.validationError(at: referenceDate, policy: policy),
            .ciphertextTooLarge(actual: 5, maximum: 4)
        )
    }

    func testMessageValidationRejectsFutureTimestampAndLongLifetime() {
        let future = makeEnvelope(
            createdAt: referenceDate.addingTimeInterval(301),
            expiresAt: referenceDate.addingTimeInterval(360)
        )
        XCTAssertEqual(future.validationError(at: referenceDate), .createdAtTooFarInFuture)

        let tooLong = makeEnvelope(
            createdAt: referenceDate,
            expiresAt: referenceDate.addingTimeInterval(MessageEnvelope.defaultTimeToLive + 1)
        )
        XCTAssertEqual(tooLong.validationError(at: referenceDate), .lifetimeTooLong)
    }

    func testEnvelopeCodableRoundTripPreservesExpiry() throws {
        let envelope = makeEnvelope(expiresAt: referenceDate.addingTimeInterval(42))
        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(MessageEnvelope.self, from: encoded)
        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.expiresAt, referenceDate.addingTimeInterval(42))
    }

    func testSeenCacheDeduplicatesValidMessagesAndEvictsAtCapacity() async {
        let cache = SeenMessageCache(capacity: 2)
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        let firstAccepted = await cache.accept(firstID)
        let firstAgainAccepted = await cache.accept(firstID)
        let secondAccepted = await cache.accept(secondID)
        let thirdAccepted = await cache.accept(thirdID)
        let firstAfterEvictionAccepted = await cache.accept(firstID)
        XCTAssertTrue(firstAccepted)
        XCTAssertFalse(firstAgainAccepted)
        XCTAssertTrue(secondAccepted)
        XCTAssertTrue(thirdAccepted)
        XCTAssertTrue(firstAfterEvictionAccepted)

        let expired = makeEnvelope(
            createdAt: referenceDate.addingTimeInterval(-2),
            expiresAt: referenceDate.addingTimeInterval(-1)
        )
        let expiredAccepted = await cache.accept(expired, at: referenceDate)
        XCTAssertFalse(expiredAccepted)
    }

    func testTransportSelectionUsesMeshAndNostrAppropriately() {
        let both = TransportAvailability(bluetoothMeshAvailable: true, nostrAvailable: true)
        let automatic = TransportSelector.select(preference: .automatic, availability: both)
        XCTAssertEqual(automatic.primary, .bluetoothMesh)
        XCTAssertEqual(automatic.fallbacks, [.nostr])
        XCTAssertEqual(automatic.dispatch, .parallel)

        let offlineFirst = TransportSelector.select(preference: .offlineFirst, availability: both)
        XCTAssertEqual(offlineFirst.orderedTransports, [.bluetoothMesh, .nostr])
        XCTAssertEqual(offlineFirst.dispatch, .sequential)

        let relayOnly = TransportSelector.select(
            preference: .automatic,
            availability: TransportAvailability(bluetoothMeshAvailable: false, nostrAvailable: true)
        )
        XCTAssertEqual(relayOnly.orderedTransports, [.nostr])

        let unavailable = TransportSelector.select(
            preference: .localOnly,
            availability: TransportAvailability(bluetoothMeshAvailable: false, nostrAvailable: true)
        )
        XCTAssertFalse(unavailable.isAvailable)
    }

    func testTransportPlanningRejectsInvalidPacket() {
        let expired = makeEnvelope(
            createdAt: referenceDate.addingTimeInterval(-2),
            expiresAt: referenceDate.addingTimeInterval(-1)
        )
        let outcome = TransportSelector.plan(
            for: expired,
            availability: TransportAvailability(bluetoothMeshAvailable: true, nostrAvailable: true),
            at: referenceDate
        )
        XCTAssertEqual(outcome, .invalidMessage(.expired))
    }

    func testDeliveryStateMachineTracksRetriesAndExpiry() throws {
        let id = UUID()
        var delivery = MessageDelivery(messageID: id, updatedAt: referenceDate)
        try delivery.beginAttempt(on: .bluetoothMesh, at: referenceDate)
        XCTAssertEqual(delivery.state, .sending)
        XCTAssertEqual(delivery.attemptedTransports, [.bluetoothMesh])

        try delivery.transition(to: .sent, at: referenceDate.addingTimeInterval(1))
        try delivery.transition(to: .relayed, at: referenceDate.addingTimeInterval(2))
        try delivery.transition(to: .delivered, at: referenceDate.addingTimeInterval(3))
        XCTAssertTrue(delivery.state.isTerminal)

        XCTAssertThrowsError(try delivery.transition(to: .queued, at: referenceDate.addingTimeInterval(4))) { error in
            XCTAssertEqual(error as? DeliveryTransitionError, .invalidTransition(from: .delivered, to: .queued))
        }

        var retry = MessageDelivery(messageID: UUID(), updatedAt: referenceDate)
        try retry.beginAttempt(on: .nostr, at: referenceDate)
        try retry.fail(.timedOut, at: referenceDate.addingTimeInterval(1))
        XCTAssertTrue(retry.state.canRetry)
        try retry.transition(to: .queued, at: referenceDate.addingTimeInterval(2))
        XCTAssertEqual(retry.state, .queued)

        var stale = MessageDelivery(messageID: UUID(), updatedAt: referenceDate)
        XCTAssertThrowsError(
            try stale.transition(
                to: .sending,
                at: referenceDate.addingTimeInterval(10),
                expiresAt: referenceDate.addingTimeInterval(10)
            )
        ) { error in
            XCTAssertEqual(error as? DeliveryTransitionError, .messageExpired)
        }
        XCTAssertEqual(stale.state, .expired)
    }

    func testIRCCommandParsingNormalizesAddressesAndReportsErrors() {
        XCTAssertEqual(
            IRCCommand.parse("/msg npub1abc hello nearby"),
            .message(target: "npub1abc", body: "hello nearby")
        )
        XCTAssertEqual(IRCCommand.parse(" /JOIN #U4PRUY "), .join("u4pruy"))
        XCTAssertEqual(IRCCommand.parse("/who #U4PR"), .who("u4pr"))
        XCTAssertEqual(
            IRCCommand.parse("/msg #u4pruy hello room"),
            .message(target: "#u4pruy", body: "hello room")
        )
        XCTAssertEqual(IRCCommand.parse("/me waves enthusiastically"), .action("waves enthusiastically"))
        XCTAssertEqual(IRCCommand.parse("/leave #U4PR"), .leave("u4pr"))
        XCTAssertEqual(IRCCommand.parse("/offline"), .offline)
        XCTAssertEqual(IRCCommand.parse("/verify npub1alice"), .verify(PeerID("npub1alice")))
        XCTAssertEqual(
            IRCCommand.parse("/relay add wss://relay.example.com"),
            .relayAdd(URL(string: "wss://relay.example.com")!)
        )

        XCTAssertEqual(
            IRCCommandParser.parse("/join invalid!"),
            .invalid(.invalidRoom("invalid!"))
        )
        XCTAssertEqual(
            IRCCommandParser.parse("/msg npub1abc"),
            .invalid(.emptyBody(command: "/msg"))
        )
        XCTAssertEqual(IRCCommandParser.parse("hello mesh"), .plainText("hello mesh"))
        XCTAssertEqual(IRCCommand.parse("/help extra"), .unknown("/help extra"))
        XCTAssertEqual(
            IRCCommandParser.parse("/relay add https://relay.example.com"),
            .invalid(.invalidRelayURL("https://relay.example.com"))
        )
    }

    private func makeEnvelope(
        remainingHops: UInt8 = 6,
        createdAt: Date? = nil,
        expiresAt: Date? = nil
    ) -> MessageEnvelope {
        let created = createdAt ?? referenceDate
        return MessageEnvelope(
            sender: PeerID("alice"),
            room: .geohash("u4pr"),
            ciphertext: Data([1]),
            createdAt: created,
            expiresAt: expiresAt ?? created.addingTimeInterval(60),
            remainingHops: remainingHops
        )
    }
}

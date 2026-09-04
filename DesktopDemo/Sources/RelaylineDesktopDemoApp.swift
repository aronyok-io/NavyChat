import Foundation
import SwiftUI

@main
struct RelaylineDesktopDemoApp: App {
    var body: some Scene {
        WindowGroup("Relayline") {
            RelaylineWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct RelaylineWindow: View {
    @StateObject private var store = DemoStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.night, Color(hex: "0B1E34"), .night],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                Sidebar(store: store)
                    .frame(width: 286)
                    .background(.night.opacity(0.78))

                Rectangle()
                    .fill(Color.border.opacity(0.78))
                    .frame(width: 1)

                ConversationView(store: store)
            }
        }
        .frame(minWidth: 980, minHeight: 660)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $store.showNewRoom) {
            JoinLocationRoomSheet(store: store)
        }
    }
}

// MARK: - Conversation shell

private struct ConversationView: View {
    @ObservedObject var store: DemoStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ConversationHeader(store: store)
                TransportStrip(store: store)

                MessageTranscript(messages: store.activeMessages, room: store.selectedConversation)

                Composer(store: store)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if store.showInspector {
                Rectangle()
                    .fill(Color.border.opacity(0.78))
                    .frame(width: 1)

                RoomInspector(store: store)
                    .frame(width: 262)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.showInspector)
    }
}

private struct ConversationHeader: View {
    @ObservedObject var store: DemoStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(store.selectedConversation.route.tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: store.selectedConversation.route.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(store.selectedConversation.route.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(store.selectedConversation.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    RoutePill(route: store.selectedConversation.route)
                }

                Text(store.selectedConversation.headerDetail)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.muted)
            }

            Spacer()

            if store.selectedConversation.route != .direct {
                PeoplePill(count: store.selectedConversation.memberCount)
            }

            HeaderIconButton(symbol: "key.fill", label: "Room key is verified") { }
            HeaderIconButton(
                symbol: store.showInspector ? "sidebar.right" : "sidebar.right",
                label: store.showInspector ? "Hide room details" : "Show room details"
            ) {
                store.showInspector.toggle()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 17)
        .background(Color.night.opacity(0.36))
    }
}

private struct TransportStrip: View {
    @ObservedObject var store: DemoStore

    private var primaryState: String {
        if store.selectedConversation.route == .direct {
            return store.relayEnabled ? "DIRECT PATH READY" : "DIRECT PATH QUEUED"
        }
        if store.selectedConversation.route == .mesh {
            return store.meshEnabled ? "MESH ONLINE" : "MESH PAUSED"
        }
        return store.relayEnabled ? "RELAY ONLINE" : "RELAY PAUSED"
    }

    private var detail: String {
        switch store.selectedConversation.route {
        case .direct:
            return store.relayEnabled ? "encrypted contact route" : "will send when a trusted route returns"
        case .mesh:
            return store.meshEnabled ? "6 nearby peers · max 3 active hops" : "Bluetooth sharing is off on this device"
        case .relay:
            return store.relayEnabled ? "3 relays · E2EE room packets" : "relay connections are off on this device"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(primaryState.contains("ONLINE") || primaryState.contains("READY") ? Color.signal : Color.alert)
                .frame(width: 7, height: 7)
                .shadow(color: Color.signal.opacity(0.8), radius: 5)

            Text(primaryState)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(Color.bright)

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.muted)

            Spacer()

            Text("never claims delivery without evidence")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.muted.opacity(0.78))
        }
        .padding(.horizontal, 24)
        .frame(height: 38)
        .background(Color.surface.opacity(0.62))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.border.opacity(0.75)).frame(height: 1)
        }
    }
}

private struct MessageTranscript: View {
    let messages: [ChatMessage]
    let room: Conversation

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    RoomMoment(room: room)
                        .padding(.bottom, 4)

                    ForEach(messages) { message in
                        ChatLine(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color.night.opacity(0.22))
    }
}

private struct RoomMoment: View {
    let room: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.border.opacity(0.75)).frame(height: 1)
            VStack(spacing: 3) {
                Text(room.route == .direct ? "SECURE DIRECT CHAT" : "ENTERED LOCATION ROOM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.muted)
                Text(room.roomDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.muted.opacity(0.82))
            }
            .fixedSize()
            Rectangle().fill(Color.border.opacity(0.75)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Entered \(room.displayName). \(room.roomDescription)")
    }
}

private struct ChatLine: View {
    let message: ChatMessage

    var body: some View {
        if message.isSystem {
            SystemLine(message: message)
        } else if message.isOutgoing {
            OutgoingChatLine(message: message)
        } else {
            IncomingChatLine(message: message)
        }
    }
}

private struct IncomingChatLine: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            InitialAvatar(initials: message.initials, tint: message.avatarTint)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(message.author)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Text(message.handle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.muted)
                    Text(message.time)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.muted.opacity(0.76))
                }

                if message.isAction {
                    Text("* \(message.author) \(message.body)")
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(Color.bright)
                        .padding(.vertical, 4)
                } else {
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Color.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.border.opacity(0.72), lineWidth: 1)
                        }
                }
            }

            Spacer(minLength: 80)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OutgoingChatLine: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 11) {
            Spacer(minLength: 96)

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 7) {
                    Text(message.time)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.muted.opacity(0.76))
                    Text("you")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.bright)
                }

                if message.isAction {
                    Text("* you \(message.body)")
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(Color.bright)
                        .padding(.vertical, 4)
                } else {
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "123E63"), Color(hex: "0D3150")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.signal.opacity(0.34), lineWidth: 1)
                        }
                }

                DeliveryLabel(delivery: message.delivery)
            }

            InitialAvatar(initials: "YO", tint: .signal)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SystemLine: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: message.systemSymbol)
                    .font(.system(size: 10, weight: .bold))
                Text(message.body)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(message.systemTint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(message.systemTint.opacity(0.10), in: Capsule())
            .overlay {
                Capsule().stroke(message.systemTint.opacity(0.22), lineWidth: 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityLabel(message.body)
    }
}

// MARK: - Composer

private struct Composer: View {
    @ObservedObject var store: DemoStore
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            if store.draft.hasPrefix("/") {
                CommandSuggestions(draft: store.draft)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.signal)
                    .padding(.bottom, 11)

                TextField("Message \(store.selectedConversation.composerName)", text: $store.draft, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .onSubmit {
                        store.sendCurrentDraft()
                    }
                    .padding(.vertical, 9)

                Button {
                    store.sendCurrentDraft()
                    isFocused = true
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.border : Color.signal, in: Circle())
                        .foregroundStyle(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.muted : Color.night)
                }
                .buttonStyle(.plain)
                .disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 13)
            .background(Color.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Color.signal.opacity(0.58) : Color.border, lineWidth: 1)
            }

            HStack(spacing: 12) {
                Label("E2EE room packet", systemImage: "lock.fill")
                    .foregroundStyle(Color.muted)
                Text("•")
                    .foregroundStyle(Color.border)
                Text("/msg  /me  /who  /help")
                    .fontDesign(.monospaced)
                    .foregroundStyle(Color.muted)
                Spacer()
                Text("⌘↵ to send")
                    .foregroundStyle(Color.muted.opacity(0.78))
            }
            .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 24)
        .padding(.top, store.draft.hasPrefix("/") ? 7 : 14)
        .padding(.bottom, 17)
        .background(Color.night.opacity(0.72))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.border.opacity(0.74)).frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: store.draft.hasPrefix("/"))
    }
}

private struct CommandSuggestions: View {
    let draft: String

    private var matches: [CommandHint] {
        let all = CommandHint.all
        let typed = draft.lowercased()
        return all.filter { typed == "/" || $0.command.hasPrefix(typed) }.prefix(3).map { $0 }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(matches) { hint in
                VStack(alignment: .leading, spacing: 3) {
                    Text(hint.command)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.bright)
                    Text(hint.description)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.border.opacity(0.86), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var store: DemoStore

    var body: some View {
        VStack(spacing: 0) {
            SidebarBrand(store: store)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    IdentityCard()

                    SidebarSection(title: "DIRECT") {
                        ForEach(store.directConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: conversation.id == store.selectedConversationID
                            ) {
                                store.select(conversation)
                            }
                        }
                    }

                    SidebarSection(title: "PLACES", trailingAction: {
                        Button {
                            store.showNewRoom = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.bright)
                                .frame(width: 24, height: 24)
                                .background(Color.signal.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Join a location room")
                    }) {
                        ForEach(store.placeConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: conversation.id == store.selectedConversationID
                            ) {
                                store.select(conversation)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 15)
            }

            VStack(spacing: 9) {
                TransportCard(
                    title: "Nearby mesh",
                    detail: store.meshEnabled ? "6 peers · 3 hops" : "Bluetooth paused",
                    symbol: "point.3.connected.trianglepath.dotted",
                    tint: store.meshEnabled ? .signal : .muted,
                    isOn: $store.meshEnabled
                )
                TransportCard(
                    title: "Global relays",
                    detail: store.relayEnabled ? "3 connected" : "Relays paused",
                    symbol: "dot.radiowaves.left.and.right",
                    tint: store.relayEnabled ? .bright : .muted,
                    isOn: $store.relayEnabled
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.border.opacity(0.12)).frame(width: 1)
        }
    }
}

private struct SidebarBrand: View {
    @ObservedObject var store: DemoStore

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.signal, Color(hex: "2563EB")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 33, height: 33)
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.night)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("RELAYLINE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.ink)
                Text("PRIVATE FIELD CHAT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.75)
                    .foregroundStyle(Color.muted)
            }

            Spacer()

            Button { store.showInspector.toggle() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.muted)
                    .frame(width: 28, height: 28)
                    .background(Color.surface.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle room details")
        }
    }
}

private struct IdentityCard: View {
    var body: some View {
        HStack(spacing: 10) {
            InitialAvatar(initials: "RK", tint: .bright, size: 31)

            VStack(alignment: .leading, spacing: 2) {
                Text("riley.k")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text("npub1…8q4s")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.muted)
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.signal)
                .accessibilityLabel("Identity key available locally")
        }
        .padding(10)
        .background(Color.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.border.opacity(0.62), lineWidth: 1)
        }
    }
}

private struct SidebarSection<Content: View, Trailing: View>: View {
    let title: String
    let content: Content
    let trailingAction: Trailing

    init(title: String, @ViewBuilder content: () -> Content) where Trailing == EmptyView {
        self.title = title
        self.content = content()
        self.trailingAction = EmptyView()
    }

    init(title: String, @ViewBuilder trailingAction: () -> Trailing, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.trailingAction = trailingAction()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.05)
                    .foregroundStyle(Color.muted)
                Spacer()
                trailingAction
            }
            .padding(.horizontal, 7)

            VStack(spacing: 3) {
                content
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(conversation.route.tint.opacity(isSelected ? 0.20 : 0.10))
                        .frame(width: 31, height: 31)
                    Image(systemName: conversation.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(conversation.route.tint)
                    if conversation.hasLiveSignal {
                        Circle()
                            .fill(Color.signal)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.night, lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(conversation.displayName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.ink : Color.ink.opacity(0.88))
                            .lineLimit(1)
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.night)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.signal, in: Capsule())
                        }
                    }
                    Text(conversation.rowDetail)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.bright.opacity(0.82) : Color.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                if conversation.route != .direct {
                    Text(conversation.route.shortLabel)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.3)
                        .foregroundStyle(conversation.route.tint.opacity(isSelected ? 1 : 0.72))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.signal.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.signal.opacity(0.24) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(conversation.displayName), \(conversation.rowDetail)")
    }
}

private struct TransportCard: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 23, height: 23)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.muted)
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Color.signal)
                .accessibilityLabel("\(title) is \(isOn ? "on" : "off")")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.surface.opacity(0.64), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.border.opacity(0.55), lineWidth: 1)
        }
    }
}

// MARK: - Room inspector

private struct RoomInspector: View {
    @ObservedObject var store: DemoStore

    private var room: Conversation { store.selectedConversation }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ROOM DETAILS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button { store.showInspector = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.muted)
                        .frame(width: 24, height: 24)
                        .background(Color.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close room details")
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    InspectorRoomCard(room: room)

                    InspectorGroup(title: "MESSAGE PATH") {
                        PathStep(
                            position: 1,
                            title: room.route == .mesh ? "Nearby devices" : "Private relay route",
                            detail: room.route == .mesh ? "Bluetooth LE / local only" : "Nostr relay packets",
                            tint: room.route.tint,
                            connectsBelow: true
                        )
                        PathStep(
                            position: 2,
                            title: room.route == .mesh ? "Hop-aware forwarding" : "Encrypted room envelope",
                            detail: room.route == .mesh ? "duplicate-safe · maximum 3 hops" : "relay sees ciphertext only",
                            tint: .bright,
                            connectsBelow: true
                        )
                        PathStep(
                            position: 3,
                            title: "Your device",
                            detail: "verified local identity",
                            tint: .signal,
                            connectsBelow: false
                        )
                    }

                    InspectorGroup(title: "PRIVACY") {
                        PrivacyRow(symbol: "key.fill", text: "Room key verified", tint: .signal)
                        PrivacyRow(symbol: "location.fill.viewfinder", text: room.route == .direct ? "No location is shared" : "Precision: \(room.scopeLabel)", tint: .bright)
                        PrivacyRow(symbol: "person.crop.circle.badge.checkmark", text: "No phone number or account", tint: .muted)
                    }
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "0A1A2D").opacity(0.94))
    }
}

private struct InspectorRoomCard: View {
    let room: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: room.route.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(room.route.tint)
                Text(room.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                RoutePill(route: room.route)
            }

            Divider().overlay(Color.border.opacity(0.8))

            InspectorData(label: "ROOM ID", value: room.headerDetail)
            InspectorData(label: "PRESENCE", value: room.memberCount > 0 ? "\(room.memberCount) consented peers" : "private contact")
        }
        .padding(13)
        .background(Color.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.border.opacity(0.78), lineWidth: 1)
        }
    }
}

private struct InspectorGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.muted)
            content
        }
    }
}

private struct PathStep: View {
    let position: Int
    let title: String
    let detail: String
    let tint: Color
    let connectsBelow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 0) {
                Text("\(position)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.night)
                    .frame(width: 20, height: 20)
                    .background(tint, in: Circle())
                if connectsBelow {
                    Rectangle()
                        .fill(Color.border)
                        .frame(width: 1, height: 21)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
    }
}

private struct PrivacyRow: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InspectorData: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.muted)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.bright)
                .lineLimit(1)
        }
    }
}

// MARK: - Join room sheet

private struct JoinLocationRoomSheet: View {
    @ObservedObject var store: DemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var precision: LocationPrecision = .neighborhood

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Join a location room")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.ink)
                    Text("Choose the smallest area that serves the conversation.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.muted)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.muted)
                        .frame(width: 28, height: 28)
                        .background(Color.surface, in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("LOCATION PRECISION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.muted)

                Picker("Location precision", selection: $precision) {
                    ForEach(LocationPrecision.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(precision.privacyNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bright)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("ROOM PREVIEW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color.muted)
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(Color.signal)
                    Text(precision.geohash)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text(precision.title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(Color.signal)
                }
                .padding(13)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                }
            }

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.signal)
                Text("Room packets are encrypted. Relays and nearby forwarders only handle ciphertext.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.signal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .tint(Color.muted)
                Button("Join room") {
                    store.joinLocationRoom(precision)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.signal)
                .foregroundStyle(Color.night)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Color.night)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Reusable visual atoms

private struct InitialAvatar: View {
    let initials: String
    let tint: Color
    var size: CGFloat = 32

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.31, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: Circle())
            .overlay {
                Circle().stroke(tint.opacity(0.25), lineWidth: 1)
            }
    }
}

private struct RoutePill: View {
    let route: ConversationRoute

    var body: some View {
        Text(route.shortLabel)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.45)
            .foregroundStyle(route.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(route.tint.opacity(0.12), in: Capsule())
    }
}

private struct PeoplePill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color.muted)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.surface.opacity(0.82), in: Capsule())
    }
}

private struct HeaderIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.muted)
                .frame(width: 34, height: 34)
                .background(Color.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.border.opacity(0.78), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct DeliveryLabel: View {
    let delivery: MessageDelivery

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: delivery.symbol)
                .font(.system(size: 9, weight: .bold))
            Text(delivery.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.1)
        }
        .foregroundStyle(delivery.tint)
    }
}

// MARK: - Demo data and interactions

private final class DemoStore: ObservableObject {
    @Published var selectedConversationID = "night-market"
    @Published var draft = ""
    @Published var meshEnabled = true
    @Published var relayEnabled = true
    @Published var showInspector = false
    @Published var showNewRoom = false
    @Published private var messagesByConversation: [String: [ChatMessage]] = DemoStore.seedMessages
    @Published private var dynamicPlaces: [Conversation] = []

    let directConversations: [Conversation] = [
        Conversation(
            id: "iris",
            displayName: "iris",
            rowDetail: "npub1…k2a8 · verified",
            headerDetail: "npub1y4…k2a8 · verified contact",
            roomDescription: "Private route with a verified contact.",
            composerName: "iris",
            memberCount: 0,
            unreadCount: 2,
            route: .direct,
            symbol: "at",
            hasLiveSignal: true,
            scopeLabel: "Private"
        ),
        Conversation(
            id: "ops",
            displayName: "relayline-ops",
            rowDetail: "system updates",
            headerDetail: "local-only system thread",
            roomDescription: "Local status events on this device.",
            composerName: "relayline-ops",
            memberCount: 0,
            unreadCount: 0,
            route: .direct,
            symbol: "terminal",
            hasLiveSignal: false,
            scopeLabel: "Private"
        )
    ]

    private let basePlaces: [Conversation] = [
        Conversation(
            id: "night-market",
            displayName: "# u4pruyd",
            rowDetail: "NEIGHBORHOOD · 12 nearby",
            headerDetail: "u4pruyd · neighborhood room key verified",
            roomDescription: "Neighborhood scope · location is represented by a shared geohash, not a profile address.",
            composerName: "#u4pruyd",
            memberCount: 12,
            unreadCount: 0,
            route: .mesh,
            symbol: "number",
            hasLiveSignal: true,
            scopeLabel: "Neighborhood"
        ),
        Conversation(
            id: "northside",
            displayName: "# u4pruy",
            rowDetail: "CITY AREA · 31 peers",
            headerDetail: "u4pruy · city-area room key verified",
            roomDescription: "City-area scope for a wider local conversation.",
            composerName: "#u4pruy",
            memberCount: 31,
            unreadCount: 4,
            route: .mesh,
            symbol: "number",
            hasLiveSignal: true,
            scopeLabel: "City area"
        ),
        Conversation(
            id: "region",
            displayName: "# u4pru",
            rowDetail: "REGION · relay backed",
            headerDetail: "u4pru · region room key verified",
            roomDescription: "Regional room with encrypted relay-backed packets.",
            composerName: "#u4pru",
            memberCount: 86,
            unreadCount: 0,
            route: .relay,
            symbol: "number",
            hasLiveSignal: false,
            scopeLabel: "Region"
        )
    ]

    var placeConversations: [Conversation] {
        basePlaces + dynamicPlaces
    }

    var allConversations: [Conversation] {
        directConversations + placeConversations
    }

    var selectedConversation: Conversation {
        allConversations.first(where: { $0.id == selectedConversationID }) ?? basePlaces[0]
    }

    var activeMessages: [ChatMessage] {
        messagesByConversation[selectedConversationID] ?? []
    }

    func select(_ conversation: Conversation) {
        selectedConversationID = conversation.id
    }

    func sendCurrentDraft() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        draft = ""

        if input.hasPrefix("/") {
            handleCommand(input)
        } else {
            append(
                ChatMessage(
                    author: "you",
                    handle: "npub1…8q4s",
                    body: input,
                    time: "now",
                    initials: "YO",
                    avatarTint: .signal,
                    isOutgoing: true,
                    delivery: selectedConversation.route == .mesh ? .relayed : .queued
                )
            )
        }
    }

    func joinLocationRoom(_ precision: LocationPrecision) {
        let id = "room-\(precision.rawValue)"
        let room = Conversation(
            id: id,
            displayName: "# \(precision.geohash)",
            rowDetail: "\(precision.title.uppercased()) · NEW ROOM",
            headerDetail: "\(precision.geohash) · \(precision.title.lowercased()) room key created",
            roomDescription: "\(precision.title) scope chosen explicitly in this demo.",
            composerName: "#\(precision.geohash)",
            memberCount: 1,
            unreadCount: 0,
            route: precision == .country ? .relay : .mesh,
            symbol: "number",
            hasLiveSignal: true,
            scopeLabel: precision.title
        )
        if !dynamicPlaces.contains(where: { $0.id == id }) {
            dynamicPlaces.append(room)
        }
        if messagesByConversation[id] == nil {
            messagesByConversation[id] = [
                ChatMessage.system("Room created locally. Share its encrypted invitation only with people you intend to reach.", tint: .signal, symbol: "lock.fill")
            ]
        }
        selectedConversationID = id
    }

    private func handleCommand(_ input: String) {
        let parts = input.split(maxSplits: 2, whereSeparator: { $0 == " " }).map(String.init)
        guard let command = parts.first?.lowercased() else { return }

        switch command {
        case "/me" where parts.count > 1:
            append(
                ChatMessage(
                    author: "you",
                    handle: "npub1…8q4s",
                    body: parts[1],
                    time: "now",
                    initials: "YO",
                    avatarTint: .signal,
                    isOutgoing: true,
                    delivery: .relayed,
                    isAction: true
                )
            )
        case "/join" where parts.count > 1:
            append(.system("Join request prepared for \(parts[1]). Confirm location scope before publishing a room invitation.", tint: .bright, symbol: "number"))
        case "/msg" where parts.count > 2:
            append(.system("Encrypted direct packet queued for \(parts[1]).", tint: .bright, symbol: "paperplane.fill"))
        case "/who":
            let count = selectedConversation.memberCount
            append(.system(count > 0 ? "\(count) consented peers currently advertise presence in this room." : "Presence is private in a direct chat.", tint: .muted, symbol: "person.2.fill"))
        case "/offline":
            relayEnabled = false
            append(.system("Relay transport paused. Nearby mesh remains available when Bluetooth is on.", tint: .alert, symbol: "wifi.slash"))
        case "/help":
            append(.system("Commands: /join, /leave, /msg, /me, /who, /verify, /relay, /offline, /help", tint: .bright, symbol: "questionmark.circle.fill"))
        default:
            append(.system("Unknown command. Try /help for available commands.", tint: .alert, symbol: "exclamationmark.triangle.fill"))
        }
    }

    private func append(_ message: ChatMessage) {
        messagesByConversation[selectedConversationID, default: []].append(message)
    }

    private static let seedMessages: [String: [ChatMessage]] = [
        "night-market": [
            .system("Room key rotated 12 min ago. Forwarders can route packets, but cannot read them.", tint: .bright, symbol: "key.fill"),
            ChatMessage(author: "maya", handle: "npub1…p3r9", body: "The west gate has a quiet entrance if anyone is looking for it.", time: "17:21", initials: "MA", avatarTint: Color(hex: "A78BFA"), delivery: .delivered),
            ChatMessage(author: "jon", handle: "npub1…7vct", body: "Thanks — I can relay that across the courtyard mesh. I see three good paths from here.", time: "17:23", initials: "JO", avatarTint: Color(hex: "34D399"), delivery: .delivered),
            ChatMessage(author: "you", handle: "npub1…8q4s", body: "Nice. I’m by the fountain. Signal is steady on my side.", time: "17:24", initials: "YO", avatarTint: .signal, isOutgoing: true, delivery: .relayed),
            ChatMessage(author: "iris", handle: "npub1…k2a8", body: "I just joined through a nearby device — still fully encrypted on my end.", time: "17:26", initials: "IR", avatarTint: Color(hex: "FBBF24"), delivery: .delivered),
            .system("iris joined through a nearby mesh path · presence was shared voluntarily", tint: .muted, symbol: "point.3.connected.trianglepath.dotted")
        ],
        "iris": [
            ChatMessage(author: "iris", handle: "npub1…k2a8", body: "I’m on the train now. The route through the relay came back up.", time: "16:58", initials: "IR", avatarTint: Color(hex: "FBBF24"), delivery: .delivered),
            ChatMessage(author: "you", handle: "npub1…8q4s", body: "Good to know. No need to share your location — message me when you’re close.", time: "17:00", initials: "YO", avatarTint: .signal, isOutgoing: true, delivery: .delivered)
        ],
        "ops": [
            .system("Identity key available only on this device. Recovery material has not been exported.", tint: .bright, symbol: "checkmark.seal.fill"),
            .system("Nearby mesh is listening. Bluetooth permission is granted.", tint: .signal, symbol: "antenna.radiowaves.left.and.right")
        ],
        "northside": [
            .system("You are viewing a broader city-area room. Nearby presence is always opt-in.", tint: .muted, symbol: "location.fill.viewfinder")
        ],
        "region": [
            .system("Relay packets are encrypted before publishing. This room does not expose a member directory.", tint: .bright, symbol: "lock.fill")
        ]
    ]
}

private struct Conversation: Identifiable {
    let id: String
    let displayName: String
    let rowDetail: String
    let headerDetail: String
    let roomDescription: String
    let composerName: String
    let memberCount: Int
    let unreadCount: Int
    let route: ConversationRoute
    let symbol: String
    let hasLiveSignal: Bool
    let scopeLabel: String
}

private enum ConversationRoute: Equatable {
    case mesh
    case relay
    case direct

    var shortLabel: String {
        switch self {
        case .mesh: "MESH"
        case .relay: "RELAY"
        case .direct: "DM"
        }
    }

    var symbol: String {
        switch self {
        case .mesh: "point.3.connected.trianglepath.dotted"
        case .relay: "dot.radiowaves.left.and.right"
        case .direct: "lock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .mesh: .signal
        case .relay: .bright
        case .direct: Color(hex: "A78BFA")
        }
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let handle: String
    let body: String
    let time: String
    let initials: String
    let avatarTint: Color
    var isOutgoing = false
    var delivery: MessageDelivery = .received
    var isAction = false
    var isSystem = false
    var systemTint: Color = .muted
    var systemSymbol = "info.circle.fill"

    static func system(_ body: String, tint: Color, symbol: String) -> ChatMessage {
        ChatMessage(
            author: "system",
            handle: "",
            body: body,
            time: "",
            initials: "",
            avatarTint: tint,
            isSystem: true,
            systemTint: tint,
            systemSymbol: symbol
        )
    }
}

private enum MessageDelivery: Equatable {
    case queued
    case relayed
    case delivered
    case received

    var label: String {
        switch self {
        case .queued: "queued"
        case .relayed: "relayed"
        case .delivered: "delivered"
        case .received: "received"
        }
    }

    var symbol: String {
        switch self {
        case .queued: "clock.fill"
        case .relayed: "arrow.triangle.branch"
        case .delivered: "checkmark.circle.fill"
        case .received: "arrow.down.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .queued: .alert
        case .relayed: .bright
        case .delivered: .signal
        case .received: .muted
        }
    }
}

private enum LocationPrecision: String, CaseIterable, Identifiable {
    case block
    case neighborhood
    case city
    case region
    case country

    var id: String { rawValue }

    var title: String {
        switch self {
        case .block: "Block"
        case .neighborhood: "Neighborhood"
        case .city: "City"
        case .region: "Region"
        case .country: "Country"
        }
    }

    var geohash: String {
        switch self {
        case .block: "u4pruydqq"
        case .neighborhood: "u4pruyd"
        case .city: "u4pruy"
        case .region: "u4pru"
        case .country: "u4"
        }
    }

    var privacyNote: String {
        switch self {
        case .block: "Most specific: a small area around one city block."
        case .neighborhood: "Balanced: useful nearby context without pinpointing an address."
        case .city: "Broad: spans a city-sized area."
        case .region: "Wide: suitable for regional coordination."
        case .country: "Broadest: country-level conversation uses global relays."
        }
    }
}

private struct CommandHint: Identifiable {
    let command: String
    let description: String
    var id: String { command }

    static let all: [CommandHint] = [
        CommandHint(command: "/msg <npub> <text>", description: "send an encrypted direct message"),
        CommandHint(command: "/me <action>", description: "post an IRC-style action"),
        CommandHint(command: "/who [room]", description: "show consented presence only"),
        CommandHint(command: "/join <geohash>", description: "prepare a location-room join"),
        CommandHint(command: "/offline", description: "pause global relay transport"),
        CommandHint(command: "/help", description: "show all supported commands")
    ]
}

// MARK: - Palette

private extension Color {
    static let night = Color(hex: "081526")
    static let surface = Color(hex: "10243D")
    static let border = Color(hex: "244665")
    static let signal = Color(hex: "38BDF8")
    static let bright = Color(hex: "7DD3FC")
    static let ink = Color(hex: "E6F4FF")
    static let muted = Color(hex: "91B4CE")
    static let alert = Color(hex: "FBBF24")

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

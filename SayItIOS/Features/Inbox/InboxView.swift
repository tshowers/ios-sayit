import SwiftUI
import FirebaseFirestore

/// Handoff 2a: every "I'm interested" is a one-on-one thread tied to its
/// post - ones you started and ones on your posts.
struct InboxView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService
    @State private var filter: InboxFilter = .all

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    private var me: String { authService.userId ?? "" }

    var body: some View {
        Group {
            if !authService.isSignedIn {
                signedOut
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Inbox").font(Theme.display(34)).foregroundStyle(Theme.text)
                            Spacer()
                            if model.unreadThreadCount > 0 {
                                KindTag(text: "\(model.unreadThreadCount) new", fill: Theme.accent100, ink: Theme.accent800)
                            }
                        }
                        filters
                        let threads = InboxRules.filter(model.inboxThreads, filter, me: me)
                        if threads.isEmpty {
                            empty
                        } else {
                            LazyVStack(spacing: 2) {
                                ForEach(threads) { thread in
                                    NavigationLink(value: AppRoute.thread(thread.id)) {
                                        InboxRow(thread: thread, me: me)
                                    }
                                    .buttonStyle(RowPressStyle(unread: thread.unreadCount(for: me) > 0))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.refreshUnreadInterests() }
            }
        }
        .task { await model.refreshUnreadInterests() }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxFilter.allCases) { option in
                    let count = InboxRules.count(model.inboxThreads, option, me: me)
                    Button {
                        filter = option
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.label)
                            Text("\(count)").opacity(0.7)
                        }
                        .font(Theme.body(12.5, .bold))
                        .padding(.horizontal, 14).frame(height: 36)
                        .foregroundStyle(filter == option ? Theme.ground : Theme.text)
                        .background(filter == option ? Theme.text : .clear, in: Capsule())
                        .overlay(Capsule().stroke(filter == option ? .clear : Theme.divider))
                    }
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.accent600)
            Text(filter == .theirs ? "No one's interested yet" : "Nothing here yet").font(Theme.display(22)).foregroundStyle(Theme.text)
            Text(filter == .theirs ? "When someone taps I'm interested on your post, you can talk it over here."
                 : "Tap I'm interested on a post and you can message the person right here.")
                .font(Theme.body(14)).foregroundStyle(Theme.neutral700).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private var signedOut: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 40, weight: .semibold)).foregroundStyle(Theme.accent600)
            Text("Your inbox").font(Theme.display(28)).foregroundStyle(Theme.text)
            Text("Tap I'm interested on a post and talk it over one-on-one here.")
                .font(Theme.body(15)).foregroundStyle(Theme.neutral700).multilineTextAlignment(.center)
            NavigationLink(value: AppRoute.signIn) {
                Text("Sign in").font(Theme.display(16)).frame(width: 200, height: 48)
            }
            .buttonStyle(PrimaryPillStyle())
            Spacer()
        }
        .padding(32)
    }
}

private struct RowPressStyle: ButtonStyle {
    let unread: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.neutral200 : (unread ? Theme.neutral100 : .clear),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct InboxRow: View {
    let thread: ChatThread
    let me: String

    var body: some View {
        let other = thread.other(me: me)
        let unread = thread.unreadCount(for: me)
        HStack(alignment: .top, spacing: 12) {
            RingAvatar(name: other.name, photoURL: other.photoURL, size: 48, ring: Theme.orgColor(other.org))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(other.name).font(Theme.body(15, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    if !other.org.isEmpty {
                        Text("at \(other.org)").font(Theme.body(12)).foregroundStyle(Theme.neutral700).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(relativeTime(thread.lastMessageAt)).font(Theme.body(12)).foregroundStyle(Theme.neutral700)
                }
                HStack {
                    Text(thread.lastSenderUid == me ? "You: \(thread.lastMessage)" : thread.lastMessage)
                        .font(Theme.body(13.5, unread > 0 ? .bold : .regular))
                        .foregroundStyle(Theme.neutral800)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if unread > 0 {
                        Text("\(unread)").font(Theme.body(11, .bold)).foregroundStyle(Theme.cream)
                            .frame(minWidth: 20, minHeight: 20).padding(.horizontal, 4)
                            .background(Theme.accent600, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    ThreadThumb(url: thread.postImageURL, size: 26, radius: 8)
                    Text([thread.postKind?.label, thread.postTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(Theme.body(12, .semibold)).foregroundStyle(Theme.neutral800).lineLimit(1)
                    Spacer(minLength: 4)
                    if thread.isMine(me: me) {
                        KindTag(text: "You're interested", fill: Theme.accent100, ink: Theme.accent800).scaleEffect(0.92)
                    } else {
                        KindTag(text: "Interested in yours", fill: Theme.sage100, ink: Theme.sage800).scaleEffect(0.92)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ThreadThumb: View {
    let url: String?
    var size: CGFloat
    var radius: CGFloat

    var body: some View {
        PostMedia(url: url, tint: Theme.sage700)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - 2b Thread

struct ThreadView: View {
    @ObservedObject var model: AppModel
    let threadId: String

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var registration: ListenerRegistration?

    private var me: String { model.auth.userId ?? "" }
    private var thread: ChatThread? { model.thread(id: threadId) }

    var body: some View {
        VStack(spacing: 0) {
            if let thread {
                header(thread)
                pinnedPost(thread)
                messageList(thread)
                quickReplies(thread)
                composer(thread)
            } else {
                ContentUnavailableView("Conversation not found", systemImage: "tray")
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard let thread else { return }
            model.markRead(thread)
            if registration == nil {
                registration = model.repository.listenToMessages(threadId: threadId) { messages in
                    Task { @MainActor in
                        self.messages = messages
                        if let current = model.thread(id: threadId) { model.markRead(current) }
                    }
                }
            }
        }
        .onDisappear {
            registration?.remove()
            registration = nil
        }
        .alert("Couldn't send", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func header(_ thread: ChatThread) -> some View {
        let other = thread.other(me: me)
        return HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40).background(Theme.neutral200, in: Circle())
            }
            .accessibilityLabel("Back")
            RingAvatar(name: other.name, photoURL: other.photoURL, size: 40, ring: Theme.orgColor(other.org))
            VStack(alignment: .leading, spacing: 1) {
                Text(other.name).font(Theme.body(15, .bold)).foregroundStyle(Theme.text)
                if !other.org.isEmpty {
                    if let org = model.org(named: other.org) {
                        NavigationLink(value: AppRoute.org(org)) {
                            (Text(other.role.isEmpty ? "at " : "\(other.role) at ") + Text(other.org).underline())
                                .font(Theme.body(12)).foregroundStyle(Theme.neutral700)
                        }
                    } else {
                        Text(other.role.isEmpty ? "at \(other.org)" : "\(other.role) at \(other.org)")
                            .font(Theme.body(12)).foregroundStyle(Theme.neutral700)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func pinnedPost(_ thread: ChatThread) -> some View {
        NavigationLink(value: AppRoute.post(thread.postId)) {
            HStack(spacing: 12) {
                ThreadThumb(url: thread.postImageURL, size: 64, radius: 18)
                VStack(alignment: .leading, spacing: 4) {
                    if let kind = thread.postKind {
                        HStack(spacing: 6) {
                            KindTag(text: kind.label, fill: Theme.sage100, ink: Theme.sage800)
                            if let price = thread.postPrice { Text(price).font(Theme.body(13, .bold)).foregroundStyle(Theme.text) }
                        }
                    }
                    Text(thread.postTitle).font(Theme.body(14, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text("View post").font(Theme.body(12, .semibold)).foregroundStyle(Theme.accentInk)
                }
                Spacer()
            }
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    private func messageList(_ thread: ChatThread) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if messages.isEmpty {
                        Text(thread.isMine(me: me) ? "Say hi - they'll see it in their inbox." : "\(thread.other(me: me).name) is interested in your post. Say hi.")
                            .font(Theme.body(12, .semibold)).foregroundStyle(Theme.neutral700)
                            .padding(.top, 20)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        bubble(message, isLast: InboxRules.isLastInRun(messages, at: index))
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .onAppear {
                if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage, isLast: Bool) -> some View {
        if message.isSystem {
            Text(systemLine(message))
                .font(Theme.body(11, .semibold)).foregroundStyle(Theme.neutral700)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Theme.neutral200, in: Capsule())
                .frame(maxWidth: .infinity)
        } else {
            let mine = message.senderUid == me
            HStack {
                if mine { Spacer(minLength: 60) }
                Text(message.text)
                    .font(Theme.body(14))
                    .foregroundStyle(mine ? Theme.cream : Theme.text)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(mine ? Theme.accent600 : Theme.neutral200,
                                in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: !mine && isLast ? 6 : 22,
                                                           bottomTrailingRadius: mine && isLast ? 6 : 22, topTrailingRadius: 22, style: .continuous))
                    .textSelection(.enabled)
                if !mine { Spacer(minLength: 60) }
            }
        }
    }

    private func systemLine(_ message: ChatMessage) -> String {
        let when = message.createdAt.map { $0.formatted(.dateTime.weekday(.abbreviated).hour().minute()) } ?? ""
        let text = message.senderUid == me ? "You tapped I'm interested" : message.text
        return when.isEmpty ? text : "\(text) · \(when)"
    }

    private func quickReplies(_ thread: ChatThread) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxRules.quickReplies, id: \.self) { reply in
                    Button {
                        Task { await send(reply, in: thread) }
                    } label: {
                        Text(reply).font(Theme.body(12.5, .semibold)).foregroundStyle(Theme.text)
                            .padding(.horizontal, 14).frame(height: 34)
                            .overlay(Capsule().stroke(Theme.divider))
                    }
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 8)
    }

    private func composer(_ thread: ChatThread) -> some View {
        HStack(spacing: 8) {
            TextField("Message \(Formatting.firstName(thread.other(me: me).name))…", text: $draft, axis: .vertical)
                .font(Theme.body(15))
                .lineLimit(1...4)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .submitLabel(.send)
                .onSubmit { Task { await send(draft, in: thread) } }
            Button {
                Task { await send(draft, in: thread) }
            } label: {
                Group {
                    if isSending { ProgressView().tint(Theme.cream) } else { Image(systemName: "paperplane.fill") }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.cream)
                .frame(width: 46, height: 46)
            }
            .buttonStyle(PrimaryPillStyle())
            .disabled(InboxRules.cleaned(draft).isEmpty || isSending)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    @MainActor
    private func send(_ text: String, in thread: ChatThread) async {
        guard !InboxRules.cleaned(text).isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await model.send(text, in: thread)
            if text == draft { draft = "" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

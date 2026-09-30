import Foundation

/// The Inbox's filters, ordering and unread rules (handoff screen 2a).
enum InboxFilter: String, CaseIterable, Identifiable {
    case all, mine, theirs
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .mine: return "I'm interested"
        case .theirs: return "In my posts"
        }
    }
}

enum InboxRules {
    static let quickReplies = ["Is this still available?", "Can you deliver?", "What's your best price?"]
    static let maxMessageLength = 1000

    static func filter(_ threads: [ChatThread], _ filter: InboxFilter, me: String) -> [ChatThread] {
        let matching: [ChatThread]
        switch filter {
        case .all: matching = threads
        case .mine: matching = threads.filter { $0.isMine(me: me) }
        case .theirs: matching = threads.filter { !$0.isMine(me: me) }
        }
        return matching.sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    static func count(_ threads: [ChatThread], _ filter: InboxFilter, me: String) -> Int {
        self.filter(threads, filter, me: me).count
    }

    /// Threads with something unread for `me` - the tab badge and "n new".
    static func unreadThreads(_ threads: [ChatThread], me: String) -> Int {
        threads.filter { $0.unreadCount(for: me) > 0 }.count
    }

    /// Email the other person only when this message is the first one they
    /// haven't read - one email per burst, not one per message.
    static func shouldEmail(recipientUnreadBefore: Int) -> Bool {
        recipientUnreadBefore == 0
    }

    static func cleaned(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxMessageLength))
    }

    /// Mine are grouped into runs; the last bubble of a run gets the tail.
    static func isLastInRun(_ messages: [ChatMessage], at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        let next = index + 1
        return next >= messages.count || messages[next].senderUid != messages[index].senderUid || messages[next].isSystem
    }
}

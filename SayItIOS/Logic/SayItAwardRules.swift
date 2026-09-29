import Foundation

/// Which SayIt awards someone qualifies for, from real data - their posts,
/// the interest they've received, their profile - so awards can't drift
/// from what actually happened (playbook: base triggers on server counts).
/// The ladder itself lives in SayItAwards (Features/Awards).
enum SayItAwardRules {
    struct Stats: Equatable {
        var postDates: [Date] = []
        var interestReceived = 0
        var profileComplete = false
    }

    static let opener = "opener"
    static let onTheRecord = "on-the-record"
    static let openForBusiness = "open-for-business"
    static let connector = "connector"
    static let conversationalist = "conversationalist"
    static let wanted = "wanted"
    static let inDemand = "in-demand"
    static let regular = "regular"
    static let legend = "legend"

    static func qualifying(_ stats: Stats, calendar: Calendar = .current) -> [String] {
        var ids: [String] = []
        if !stats.postDates.isEmpty { ids.append(onTheRecord) }
        if stats.profileComplete { ids.append(openForBusiness) }
        if stats.interestReceived >= 1 { ids.append(wanted) }
        if stats.interestReceived >= 5 { ids.append(inDemand) }
        if distinctDays(stats.postDates, calendar: calendar) >= 3 { ids.append(regular) }
        if stats.postDates.count >= 25 { ids.append(legend) }
        return ids
    }

    static func distinctDays(_ dates: [Date], calendar: Calendar = .current) -> Int {
        Set(dates.map { calendar.startOfDay(for: $0) }).count
    }
}

import Foundation

/// Reads loosely-typed Firestore fields the way the web app does: SayIt's
/// documents were written by several generations of TODD code, so the same
/// field can be a string, number, date, or missing. Firestore `Timestamp`s
/// are converted to `Date` by `FirestoreValues.normalize` before they get
/// here, which keeps this file (and everything that uses it) free of
/// Firebase so it can be unit tested on its own.
enum FieldReader {
    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespaces))
        default:
            return nil
        }
    }

    static func bool(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            return ["true", "1", "yes"].contains(string.lowercased())
        default:
            return false
        }
    }

    /// Accepts a `Date`, an ISO-8601 string (with or without fractional
    /// seconds), epoch seconds/milliseconds, or a `{seconds: n}` map.
    static func date(_ value: Any?) -> Date? {
        switch value {
        case let date as Date:
            return date
        case let string as String:
            return parseISODate(string)
        case let number as NSNumber:
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 100_000_000_000 ? raw / 1000 : raw)
        case let map as [String: Any]:
            if let seconds = map["seconds"] as? NSNumber ?? map["_seconds"] as? NSNumber {
                return Date(timeIntervalSince1970: seconds.doubleValue)
            }
            return nil
        default:
            return nil
        }
    }

    static func stringArray(_ value: Any?) -> [String] {
        (value as? [Any] ?? []).compactMap { string($0) }
    }

    private static func parseISODate(_ raw: String) -> Date? {
        let string = raw.trimmingCharacters(in: .whitespaces)
        guard !string.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}

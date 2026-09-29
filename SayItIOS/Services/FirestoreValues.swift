import Foundation
import FirebaseFirestore

/// Converts Firestore-specific values (currently `Timestamp`) into plain
/// Foundation types, recursively, so the models can decode documents without
/// importing Firebase (see FieldReader).
enum FirestoreValues {
    static func normalize(_ data: [String: Any]) -> [String: Any] {
        data.mapValues(normalizeValue)
    }

    private static func normalizeValue(_ value: Any) -> Any {
        switch value {
        case let timestamp as Timestamp:
            return timestamp.dateValue()
        case let map as [String: Any]:
            return normalize(map)
        case let array as [Any]:
            return array.map(normalizeValue)
        default:
            return value
        }
    }

    /// Drops nil values so Firestore never stores explicit nulls for
    /// optional fields (the web strips `undefined` the same way).
    static func compact(_ fields: [String: Any?]) -> [String: Any] {
        fields.compactMapValues { $0 }
    }
}

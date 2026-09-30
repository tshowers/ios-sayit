import Foundation

/// An organization as SayIt knows it: the people whose public profiles
/// share a business name. There's no verification yet, so nothing is ever
/// labeled "verified".
struct Org: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var category: String
    var city: String
    var about: String
    var website: String
    var memberUids: [String]
    var colorIndex: Int

    var initial: String { String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased() }
}

enum OrgDirectory {
    /// The design's org tones - legible under cream text.
    static let paletteSize = 5

    /// "Kettle & Co. Bakery " -> "kettle-co-bakery"
    static func slug(_ name: String) -> String {
        let lowered = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return parts.joined(separator: "-")
    }

    /// Same name, same color, on every device.
    static func colorIndex(for name: String) -> Int {
        let value = slug(name).unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return Int(value % UInt32(paletteSize))
    }

    /// Groups public profiles into orgs by business name, busiest first.
    static func orgs(from profiles: [SayItProfile]) -> [Org] {
        var byId: [String: Org] = [:]
        for profile in profiles {
            let name = profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = slug(name)
            guard !id.isEmpty else { continue }
            if var org = byId[id] {
                org.memberUids.append(profile.uid)
                if org.category.isEmpty { org.category = profile.businessCategory }
                if org.city.isEmpty { org.city = profile.location }
                if org.about.isEmpty { org.about = profile.pinnedIntro.isEmpty ? profile.tagline : profile.pinnedIntro }
                if org.website.isEmpty { org.website = profile.websiteURL }
                byId[id] = org
            } else {
                byId[id] = Org(id: id, name: name, category: profile.businessCategory, city: profile.location,
                               about: profile.pinnedIntro.isEmpty ? profile.tagline : profile.pinnedIntro,
                               website: profile.websiteURL, memberUids: [profile.uid], colorIndex: colorIndex(for: name))
            }
        }
        return byId.values.sorted {
            $0.memberUids.count != $1.memberUids.count ? $0.memberUids.count > $1.memberUids.count : $0.name < $1.name
        }
    }

    /// The design's search: name, category, and city.
    static func search(_ orgs: [Org], _ text: String) -> [Org] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return orgs }
        return orgs.filter { "\($0.name) \($0.category) \($0.city)".lowercased().contains(query) }
    }
}

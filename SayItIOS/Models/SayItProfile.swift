import Foundation

/// `tenants/{masterTenantId}/say-it-profiles/{uid}` - a person's public
/// SayIt business profile (the web's /profile page edits the same doc).
struct SayItProfile: Equatable {
    var uid: String
    var displayName = ""
    var businessName = ""
    var businessCategory = ""
    var location = ""
    var tagline = ""
    var pinnedIntro = ""
    var websiteURL = ""
    /// "What do you do or need?" - stored as both `intentText` and the
    /// older `sellText`.
    var intentText = ""
    var handle: String?
    var photoURL: String?
    var blockedUids: [String] = []
    /// Job title shown as "{Role} at {Org}". Stored as `jobTitle` - never
    /// `role`, which elsewhere in TODD is the permission level.
    var role = ""
    var feedLayout: FeedLayout?
    /// Liked posts - the same field the web board keeps favorites in.
    var favoritePostIds: [String] = []

    init(uid: String) {
        self.uid = uid
    }

    init(uid: String, data: [String: Any]) {
        self.uid = FieldReader.string(data["uid"]) ?? uid
        displayName = FieldReader.string(data["displayName"]) ?? ""
        businessName = FieldReader.string(data["businessName"]) ?? FieldReader.string(data["companyName"]) ?? ""
        businessCategory = FieldReader.string(data["businessCategory"]) ?? FieldReader.string(data["industry"]) ?? ""
        location = FieldReader.string(data["location"]) ?? ""
        tagline = FieldReader.string(data["tagline"]) ?? ""
        pinnedIntro = FieldReader.string(data["pinnedIntro"]) ?? ""
        websiteURL = FieldReader.string(data["websiteUrl"]) ?? ""
        intentText = FieldReader.string(data["intentText"]) ?? FieldReader.string(data["sellText"]) ?? ""
        handle = FieldReader.string(data["handle"])
        photoURL = FieldReader.string(data["photoURL"])
        blockedUids = FieldReader.stringArray(data["blockedUids"])
        role = FieldReader.string(data["jobTitle"]) ?? ""
        feedLayout = FieldReader.string(data["feedLayout"]).flatMap(FeedLayout.init(rawValue:))
        favoritePostIds = FieldReader.stringArray(data["favoritePostIds"])
    }

    var isComplete: Bool { ProfileValidation.validate(self) == nil }
}

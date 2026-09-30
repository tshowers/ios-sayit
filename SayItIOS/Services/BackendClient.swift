import Foundation

/// Calls to the TODD backend (api.taliferro.tech) that the web app makes too.
struct BackendClient {
    let config: AppConfig
    let idToken: () async throws -> String

    /// AI rating for a new post via `POST /openai`, sent with the same API
    /// key header the web uses. Never throws: if the call or the parse
    /// fails the post goes out unrated, exactly like the web.
    func moderate(content: String, category: String) async -> Moderation.Result? {
        var request = URLRequest(url: config.apiBaseURL.appending(path: "openai"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.backendAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["prompt": Moderation.prompt(content: content, category: category)])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let reply = json["response"] as? String else {
            return nil
        }
        return Moderation.parse(reply, fallbackCategory: category)
    }

    /// Wizard answers to the shared TODD profile - `POST /onboarding/profile`,
    /// which only fills blank fields and never overwrites a profile.
    func submitOnboardingProfile(_ body: [String: Any]) async throws {
        var request = URLRequest(url: config.apiBaseURL.appending(path: "onboarding/profile"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await idToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendError.requestFailed("Unable to save your profile.")
        }
    }

    /// Saves the SayIt profile through `POST /sayit/profile/complete`, the
    /// endpoint the web profile page uses (it writes the say-it-profiles doc
    /// server-side and marks it public).
    func saveProfile(_ profile: SayItProfile, email: String?) async throws {
        let website = ProfileValidation.normalizedWebsite(profile.websiteURL) ?? ""
        let intent = profile.intentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "uid": profile.uid,
            "websiteUrl": website,
            "sellText": intent,
            "intentText": intent,
            "email": (email ?? "").lowercased(),
            "displayName": profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessName": profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessCategory": profile.businessCategory.trimmingCharacters(in: .whitespacesAndNewlines),
            "location": profile.location.trimmingCharacters(in: .whitespacesAndNewlines),
            "tagline": profile.tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            "pinnedIntro": profile.pinnedIntro.trimmingCharacters(in: .whitespacesAndNewlines),
            "publicProfile": true,
            "profileIntentCompleted": true,
        ]

        var request = URLRequest(url: config.apiBaseURL.appending(path: "sayit/profile/complete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await idToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw BackendError.requestFailed(message ?? "Unable to save your profile. Please try again.")
        }
    }
}

extension BackendClient {
    /// Emails the support inbox about a new report so it can be acted on
    /// within 24 hours (what App Store guideline 1.2 expects and what the
    /// community guidelines promise). Best-effort: the report is already
    /// saved in `post-reports` either way. `isTestSend` tells /send-email to
    /// send now and not log it as contact activity - it's an internal alert.
    func notifyReport(post: Post, reason: String, reporterEmail: String?, postURL: URL) async {
        let escaped = post.content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let text = """
        A Say It post was reported from the iOS app.

        Reason: \(reason)
        Post: \(postURL.absoluteString)
        Author uid: \(post.authorUid ?? "unknown")
        Reported by: \(reporterEmail ?? "unknown")

        "\(post.content)"
        """
        let html = """
        <p>A Say It post was reported from the iOS app.</p>
        <p><b>Reason:</b> \(reason)<br><b>Post:</b> <a href="\(postURL.absoluteString)">\(postURL.absoluteString)</a><br>\
        <b>Author uid:</b> \(post.authorUid ?? "unknown")<br><b>Reported by:</b> \(reporterEmail ?? "unknown")</p>
        <blockquote>\(escaped)</blockquote>
        """
        let payload: [String: Any] = [
            "to": AppConfig.supportEmail,
            "subject": "Say It report: \(reason)",
            "text": text,
            "html": html,
            "tenantId": config.masterTenantId,
            "isTestSend": true,
            "sourceSystem": "sayit-ios",
        ]

        guard let token = try? await idToken(), let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: config.apiBaseURL.appending(path: "send-email"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }
}

extension BackendClient {
    /// Emails the other person when they have a new message they haven't
    /// seen (InboxRules.shouldEmail - once per burst). The link opens the
    /// post, and the app if it's installed. Best-effort; never throws.
    func notifyNewMessage(to email: String, from sender: String, postTitle: String, text: String, postURL: URL) async {
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        let subject = "\(sender) replied about \"\(postTitle.prefix(60))\""
        let payload: [String: Any] = [
            "to": email,
            "subject": subject,
            "text": "\(sender) sent you a message on Say It:\n\n\"\(text)\"\n\nReply in the Say It app: \(postURL.absoluteString)",
            "html": "<p><b>\(escape(sender))</b> sent you a message on Say It about <b>\(escape(postTitle))</b>:</p><blockquote>\(escape(text))</blockquote><p><a href=\"\(postURL.absoluteString)\">Reply in Say It</a></p>",
            "tenantId": config.masterTenantId,
            "isTestSend": true,
            "sourceSystem": "sayit-ios",
        ]
        guard let token = try? await idToken(), let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: config.apiBaseURL.appending(path: "send-email"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }
}

enum BackendError: LocalizedError {
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let message): return message
        }
    }
}

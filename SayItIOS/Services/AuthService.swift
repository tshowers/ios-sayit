import Foundation
import FirebaseAuth

/// Firebase Auth state for the app. Unlike the other TODD apps, SayIt can be
/// browsed signed out - signing in (native Apple/Google via TODDAuthKit) is
/// only needed to post, comment, send interest, or edit a profile - so there
/// is no biometric session gate: nothing here is private to the device owner.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true

    private let config: AppConfig
    private var handle: AuthStateDidChangeListenerHandle?

    init(config: AppConfig) {
        self.config = config
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.isLoading = false
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var userId: String? { currentUser?.uid }
    var isSignedIn: Bool { currentUser != nil }

    /// Best available name for a signed-in person with no SayIt profile yet.
    var fallbackDisplayName: String {
        if let name = currentUser?.displayName?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return name }
        if let email = currentUser?.email, let local = email.split(separator: "@").first { return String(local) }
        return "User"
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func freshIdToken() async throws -> String {
        guard let user = currentUser else { throw AuthServiceError.notSignedIn }
        return try await user.getIDToken()
    }

    /// Creates (or finds) this person's TODD account and tenant after a
    /// fresh native sign-in - `POST /api/mobile/auth/bootstrap`, the same
    /// call every TODD app makes. The shared profile/account screen
    /// (TODDProfileKit) depends on it.
    func bootstrapAccount() async throws {
        var request = URLRequest(url: config.apiBaseURL.appending(path: "mobile/auth/bootstrap"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await freshIdToken())", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AuthServiceError.bootstrapFailed
        }
    }
}

enum AuthServiceError: LocalizedError {
    case notSignedIn
    case bootstrapFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to continue."
        case .bootstrapFailed:
            return "Unable to set up your account. Please try again."
        }
    }
}

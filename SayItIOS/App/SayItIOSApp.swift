import SwiftUI
import FirebaseCore
import TODDAuthKit

@main
struct SayItIOSApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var model: AppModel

    init() {
        #if DEBUG
        // UI tests launch with -uiTestFreshInstall to start from first launch.
        if ProcessInfo.processInfo.arguments.contains("-uiTestFreshInstall") {
            ["sayit.browsingAsGuest", OnboardingDraft.storageKey, "todd-awards.sayit.unlocked", "todd-awards.sayit.pending"]
                .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        }
        #endif
        FirebaseApp.configure()
        let config = AppConfig.fromBundle()
        let auth = AuthService(config: config)
        _authService = StateObject(wrappedValue: auth)
        _model = StateObject(wrappedValue: AppModel(config: config, auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, authService: authService)
                .onOpenURL { url in
                    if GoogleSignInHelper.handle(url) { return }
                    openLink(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { openLink(url) }
                }
        }
    }

    private func openLink(_ url: URL) {
        if let postId = PostLinks.postId(from: url) {
            model.openPost(postId)
        }
    }
}

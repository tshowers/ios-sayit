import SwiftUI
import FirebaseCore
import TODDAuthKit

@main
struct SayItIOSApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var model: AppModel

    init() {
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
            model.linkedPostId = postId
        }
    }
}

import SwiftUI

/// Sheet that walks someone through what they need before taking part:
/// sign in, then accept the community guidelines. Calls `onReady` once both
/// are done so the action they tapped can carry on.
struct ParticipationGate: View {
    @ObservedObject var model: AppModel
    @ObservedObject var authService: AuthService
    let onReady: () -> Void

    init(model: AppModel, onReady: @escaping () -> Void) {
        self.model = model
        self.authService = model.auth
        self.onReady = onReady
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isSignedIn {
                    SignInView(model: model)
                } else {
                    CommunityGuidelinesView(onAgree: {
                        model.termsAccepted = true
                        onReady()
                    })
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GateCancelButton()
                }
            }
        }
        .onChange(of: authService.isSignedIn) { _, signedIn in
            if signedIn, model.termsAccepted { onReady() }
        }
    }
}

private struct GateCancelButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Cancel") { dismiss() }
    }
}

extension AppModel {
    var canParticipate: Bool { auth.isSignedIn && termsAccepted }
}

import SwiftUI
import TODDAuthKit

/// Native Apple/Google sign-in from TODDAuthKit. Pushed as a page wherever
/// an action needs an account, and shown in place inside the wizard.
/// Signing in here is also agreeing to the community guidelines (App Store
/// guideline 1.2), which the page says and links to.
struct SignInView: View {
    @ObservedObject var model: AppModel
    var title = "Sign in to Say It"
    var reason = "Post, comment, and let businesses know you're interested."
    /// Pushed pages pop back after signing in; the wizard handles it itself.
    var popsOnSignIn = true
    var onSignedIn: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage = ""
    @State private var isFinishing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image("SayItLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 84)
                    .padding(.top, 24)

                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                SignInButtons(model: model, isFinishing: $isFinishing, errorMessage: $errorMessage, onSignedIn: finished)
                    .padding(.horizontal, 32)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func finished() {
        onSignedIn?()
        if popsOnSignIn { dismiss() }
    }
}

/// Apple + Google (+ email in Debug builds) with the guidelines agreement.
/// Shared by SignInView and the wizard's last step.
struct SignInButtons: View {
    @ObservedObject var model: AppModel
    @Binding var isFinishing: Bool
    @Binding var errorMessage: String
    let onSignedIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButtonView(
                onSignedIn: { Task { await finish() } },
                onError: { errorMessage = $0.localizedDescription }
            )
            SignInWithGoogleButtonView(
                onSignedIn: { Task { await finish() } },
                onError: { errorMessage = $0.localizedDescription }
            )
            #if DEBUG
            DebugEmailSignInView(onSignedIn: { Task { await finish() } })
            #endif

            if isFinishing {
                ProgressView()
            }

            VStack(spacing: 4) {
                Text("By continuing you agree to keep Say It respectful: no spam, harassment, or objectionable content.")
                NavigationLink("Read the Community Guidelines", value: AppRoute.guidelines)
                    .fontWeight(.semibold)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
        }
        .disabled(isFinishing)
    }

    /// Sets up the TODD account behind the sign-in. Failing that isn't fatal
    /// for SayIt - posting only needs Firebase Auth - so it never blocks.
    @MainActor
    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }
        model.recordGuidelinesAccepted()
        try? await model.auth.bootstrapAccount()
        onSignedIn()
    }
}

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

/// Apple + Google + email/password (for existing accounts, e.g. App
/// Review's demo account) with the guidelines agreement.
/// Shared by SignInView and the wizard's last step.
struct SignInButtons: View {
    @ObservedObject var model: AppModel
    @Binding var isFinishing: Bool
    @Binding var errorMessage: String
    let onSignedIn: () -> Void
    /// App Store guideline 1.2: an explicit agreement before signing in.
    @State private var agreed = false

    var body: some View {
        VStack(spacing: 12) {
            agreement

            Group {
            SignInWithAppleButtonView(
                onSignedIn: { Task { await finish() } },
                onError: { errorMessage = $0.localizedDescription }
            )
            SignInWithGoogleButtonView(
                onSignedIn: { Task { await finish() } },
                onError: { errorMessage = $0.localizedDescription }
            )
            EmailSignInView(onSignedIn: { Task { await finish() } })
            }
            .disabled(!agreed)
            .opacity(agreed ? 1 : 0.45)

            if isFinishing {
                ProgressView()
            }
        }
        .disabled(isFinishing)
        .onAppear { agreed = agreed || model.hasAcceptedGuidelines }
    }

    private var agreement: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $agreed) {
                Text("I agree to the Terms of Use (EULA) and the Community Guidelines. There is zero tolerance for objectionable content or abusive users.")
                    .font(.footnote)
            }
            .toggleStyle(AgreementCheckboxStyle())
            HStack(spacing: 14) {
                Link("Terms of Use (EULA)", destination: AppConfig.termsURL)
                NavigationLink("Community Guidelines", value: AppRoute.guidelines)
            }
            .font(.footnote.weight(.semibold))
            .padding(.leading, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// A tappable checkbox for the sign-in agreement.
struct AgreementCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Checked" : "Not checked")
    }
}


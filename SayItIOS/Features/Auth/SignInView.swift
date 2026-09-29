import SwiftUI
import TODDAuthKit

/// Native Apple/Google sign-in from TODDAuthKit, shown only when someone
/// tries to do something that needs an account - browsing never does.
struct SignInView: View {
    @ObservedObject var model: AppModel
    var reason = "Sign in to post, comment, and let businesses know you're interested."

    @State private var errorMessage = ""
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("SayItLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 84)

            Text("Say It")
                .font(.largeTitle.bold())
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

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
            }
            .padding(.horizontal, 32)
            .disabled(isFinishing)

            if isFinishing {
                ProgressView()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    /// Sets up the TODD account behind the sign-in. Failing that isn't fatal
    /// for SayIt - posting only needs Firebase Auth - so it never blocks.
    @MainActor
    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }
        try? await model.auth.bootstrapAccount()
        await model.refreshAccount()
    }
}

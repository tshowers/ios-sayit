import FirebaseAuth
import SwiftUI

/// Email and password sign-in for existing accounts, folded away under
/// Apple and Google. It's how App Review signs in with the demo account
/// (guideline 2.1: Apple asks for a user name and password), and it works
/// for anyone with a TODD email/password account. It doesn't create
/// accounts: new people use Sign in with Apple or Google.
struct EmailSignInView: View {
    let onSignedIn: () -> Void

    @State private var isExpanded = false
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await signIn() } }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || isSubmitting)
            } else {
                Button("Sign in with email") {
                    withAnimation { isExpanded = true }
                    focusedField = .email
                }
                .font(.footnote.weight(.semibold))
            }
        }
    }

    private func signIn() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = ""
        defer { isSubmitting = false }
        do {
            try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            onSignedIn()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        switch AuthErrorCode.Code(rawValue: (error as NSError).code) {
        case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail:
            return "That email and password don't match an account."
        case .userDisabled:
            return "This account has been suspended."
        case .tooManyRequests:
            return "Too many attempts. Wait a minute and try again."
        case .networkError:
            return "No connection. Check your internet and try again."
        default:
            return error.localizedDescription
        }
    }
}

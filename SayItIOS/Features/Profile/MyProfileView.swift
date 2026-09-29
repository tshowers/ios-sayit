import SwiftUI
import TODDProfileKit

/// The Me tab: your public SayIt profile plus account, safety, and legal.
struct MyProfileView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    var body: some View {
        NavigationStack {
            List {
                if authService.isSignedIn {
                    Section {
                        NavigationLink(value: AppRoute.profileEditor) {
                            HStack(spacing: 12) {
                                AvatarView(urlString: model.profile?.photoURL ?? authService.currentUser?.photoURL?.absoluteString, name: model.displayName, size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName).font(.headline)
                                    Text(model.profile?.isComplete == true ? "Edit your Say It profile" : "Finish your Say It profile")
                                        .font(.subheadline)
                                        .foregroundStyle(model.profile?.isComplete == true ? Color.secondary : Color.accentColor)
                                }
                            }
                        }
                    }

                    Section {
                        NavigationLink(value: AppRoute.awards) {
                            HStack {
                                Label("Awards", systemImage: "trophy")
                                Spacer()
                                Text("\(model.awards.unlockedCount) of \(model.awards.totalCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Account") {
                        NavigationLink("TODD Account", value: AppRoute.account)
                        NavigationLink("Blocked People", value: AppRoute.blocked)
                        Button("Sign Out", role: .destructive) {
                            do { try authService.signOut() } catch { errorMessage = error.localizedDescription }
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get found on Say It").font(.headline)
                            Text("Sign in to post, comment, and set up a free public profile for your business.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            NavigationLink("Sign In", value: AppRoute.signIn)
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("About") {
                    NavigationLink("Community Guidelines", value: AppRoute.guidelines)
                    Link("Terms", destination: AppConfig.termsURL)
                    Link("Privacy Policy", destination: AppConfig.privacyURL)
                    if let mail = URL(string: "mailto:\(AppConfig.supportEmail)?subject=Say%20It%20support") {
                        Link("Contact Support", destination: mail)
                    }
                    Link("Say It on the Web", destination: model.config.webBaseURL)
                }
            }
            .navigationTitle("Me")
            .appDestinations(model)
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

/// TODDProfileKit's shared profile screen, with Delete Account.
struct AccountView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ProfileView(
            api: ProfileAPI(
                baseURL: model.config.apiBaseURL,
                idToken: { @MainActor [weak auth = model.auth] in
                    guard let auth else { throw AuthServiceError.notSignedIn }
                    return try await auth.freshIdToken()
                }
            ),
            appName: "Say It",
            onAccountDeleted: {
                OnboardingDraft.clear()
                try? model.auth.signOut()
            }
        )
    }
}

/// Edits `say-it-profiles/{uid}` through the same backend endpoint as the
/// web's profile page, with the same validation.
struct SayItProfileEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SayItProfile(uid: "")
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $draft.displayName)
                    .textContentType(.name)
                TextField("What do you do or need?", text: $draft.intentText, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Required")
            } footer: {
                Text("This is how people find you. Example: \"Commercial cleaning for offices in Seattle.\"")
            }

            Section("Business") {
                TextField("Business name", text: $draft.businessName)
                    .textContentType(.organizationName)
                TextField("Category", text: $draft.businessCategory)
                TextField("Location", text: $draft.location)
                    .textContentType(.addressCityAndState)
                TextField("Website", text: $draft.websiteURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Introduce yourself") {
                TextField("Tagline", text: $draft.tagline)
                TextField("Pinned intro", text: $draft.pinnedIntro, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Text("Your profile is public and appears in the Say It business directory.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Say It Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                }
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            draft = model.profile ?? SayItProfile(uid: model.auth.userId ?? "")
            if draft.displayName.isEmpty { draft.displayName = model.auth.fallbackDisplayName }
        }
    }

    @MainActor
    private func save() async {
        if let problem = ProfileValidation.validate(draft) {
            errorMessage = problem
            return
        }
        guard let uid = model.auth.userId else { return }
        draft.uid = uid
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await model.backend.saveProfile(draft, email: model.auth.currentUser?.email)
            var saved = draft
            saved.websiteURL = ProfileValidation.normalizedWebsite(draft.websiteURL) ?? ""
            model.profileSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BlockedPeopleView: View {
    @ObservedObject var model: AppModel
    @State private var errorMessage: String?

    /// Names for blocked uids, taken from posts still in the feed.
    private func name(for uid: String) -> String {
        model.posts.first(where: { $0.authorUid == uid })?.displayName ?? "Someone you blocked"
    }

    var body: some View {
        List {
            if model.blockedUids.isEmpty {
                Text("You haven't blocked anyone.").foregroundStyle(.secondary)
            }
            ForEach(model.blockedUids.sorted(), id: \.self) { uid in
                HStack {
                    Text(name(for: uid))
                    Spacer()
                    Button("Unblock") {
                        Task {
                            do { try await model.unblock(uid) } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Blocked People")
    }
}

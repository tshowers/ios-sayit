import SwiftUI
import TODDAwardsKit

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var authService: AuthService
    @ObservedObject var awards: AwardsService

    init(model: AppModel, authService: AuthService) {
        self.model = model
        self.authService = authService
        self.awards = model.awards
    }

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
            } else if !authService.isSignedIn && !model.isBrowsingAsGuest {
                // First launch signed out: write a first post, sign in last.
                OnboardingWizardView(model: model)
            } else {
                TabView(selection: $model.selectedTab) {
                    FeedView(model: model)
                        .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right") }
                        .tag(AppTab.feed)

                    InterestInboxView(model: model)
                        .tabItem { Label("Interest", systemImage: "tray") }
                        .badge(model.unreadInterestCount)
                        .tag(AppTab.interest)

                    MyProfileView(model: model)
                        .tabItem { Label("Me", systemImage: "person.crop.circle") }
                        .tag(AppTab.me)
                }
                .overlay(alignment: .top) {
                    if model.isPublishingDraft {
                        Label("Posting your first post…", systemImage: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
            }
        }
        .task { model.startFeed() }
        .task(id: authService.userId) { await model.refreshAccount() }
        .fullScreenCover(item: Binding(
            get: { awards.pendingUnlock },
            set: { if $0 == nil { awards.dismissCurrentUnlock() } }
        )) { award in
            AwardUnlockView(
                award: award,
                appName: "Say It",
                unlockedCount: awards.unlockedCount,
                totalCount: awards.totalCount,
                onContinue: { awards.dismissCurrentUnlock() }
            )
        }
    }
}

/// The page for a pushed route, shared by every tab's NavigationStack.
struct AppDestination: View {
    @ObservedObject var model: AppModel
    let route: AppRoute

    var body: some View {
        switch route {
        case .post(let id):
            PostDetailView(model: model, postId: id)
        case .compose:
            ComposerView(model: model, initialCategory: "all")
        case .report(let post):
            ReportView(model: model, post: post)
        case .signIn:
            SignInView(model: model)
        case .guidelines:
            CommunityGuidelinesView()
        case .profileEditor:
            SayItProfileEditor(model: model)
        case .account:
            AccountView(model: model)
        case .blocked:
            BlockedPeopleView(model: model)
        case .awards:
            AwardsGridView(awardsService: model.awards)
                .navigationTitle("Awards")
                .task { await model.awards.sync() }
        }
    }
}

extension View {
    /// Pushes `AppDestination` for any `AppRoute` value in this stack.
    func appDestinations(_ model: AppModel) -> some View {
        navigationDestination(for: AppRoute.self) { AppDestination(model: model, route: $0) }
    }
}

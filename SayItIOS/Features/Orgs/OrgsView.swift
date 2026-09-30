import SwiftUI

/// Handoff 2c: the organizations people post from, built from SayIt
/// profiles that share a business name. No follow and no "verified" (there
/// is no verification yet), per the product owner.
struct OrgsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService
    @State private var search = ""
    @State private var isLoading = false

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    var body: some View {
        Group {
            if !authService.isSignedIn {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "building.2").font(.system(size: 40, weight: .semibold)).foregroundStyle(Theme.accent600)
                    Text("Organizations").font(Theme.display(28)).foregroundStyle(Theme.text)
                    Text("Sign in to browse the businesses and organizations posting on Say It.")
                        .font(Theme.body(15)).foregroundStyle(Theme.neutral700).multilineTextAlignment(.center)
                    NavigationLink(value: AppRoute.signIn) {
                        Text("Sign in").font(Theme.display(16)).frame(width: 200, height: 48)
                    }
                    .buttonStyle(PrimaryPillStyle())
                    Spacer()
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Orgs").font(Theme.display(34)).foregroundStyle(Theme.text)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.neutral700)
                            TextField("Search organizations", text: $search)
                                .font(Theme.body(15))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(Theme.surface, in: Capsule())

                        let orgs = OrgDirectory.search(model.orgs, search)
                        if isLoading && model.orgs.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else if orgs.isEmpty {
                            Text(search.isEmpty ? "No organizations yet. Add your business name to your profile and you'll show up here."
                                 : "No organizations match \u{201C}\(search)\u{201D}.")
                                .font(Theme.body(14)).foregroundStyle(Theme.neutral700)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(orgs) { org in
                                    NavigationLink(value: AppRoute.org(org)) { OrgRow(org: org) }
                                        .buttonStyle(PressScaleStyle(scale: 0.98))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.loadOrgs() }
            }
        }
        .task(id: authService.userId) {
            guard authService.isSignedIn, model.orgs.isEmpty else { return }
            isLoading = true
            await model.loadOrgs()
            isLoading = false
        }
    }
}

struct OrgCircle: View {
    let org: Org
    var size: CGFloat
    var body: some View {
        Circle().fill(Theme.orgPalette[org.colorIndex % Theme.orgPalette.count])
            .frame(width: size, height: size)
            .overlay(Text(org.initial).font(Theme.display(size * 0.42)).foregroundStyle(Theme.cream))
            .accessibilityHidden(true)
    }
}

struct OrgRow: View {
    let org: Org
    var body: some View {
        HStack(spacing: 12) {
            OrgCircle(org: org, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(org.name).font(Theme.display(17)).foregroundStyle(Theme.text).lineLimit(1)
                let detail = [org.category, org.city].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(Theme.body(12)).foregroundStyle(Theme.neutral700).lineLimit(1)
                }
                Text("\(org.memberUids.count) \(org.memberUids.count == 1 ? "person" : "people") posting")
                    .font(Theme.body(12, .semibold)).foregroundStyle(Theme.neutral800)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.neutral700)
        }
        .padding(12)
        .background(Theme.neutral100, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 2d Org profile

struct OrgProfileView: View {
    @ObservedObject var model: AppModel
    let org: Org

    private enum Section: String, CaseIterable { case posts = "Posts", people = "People", about = "About" }

    @Environment(\.dismiss) private var dismiss
    @State private var section: Section = .posts
    @State private var posts: [Post] = []
    @State private var people: [SayItProfile] = []
    @State private var isLoading = true

    private var color: Color { Theme.orgPalette[org.colorIndex % Theme.orgPalette.count] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    UnevenRoundedRectangle(bottomLeadingRadius: 44, bottomTrailingRadius: 44, style: .continuous)
                        .fill(color)
                        .frame(height: 170)
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.cream)
                            .frame(width: 40, height: 40).background(Theme.cream.opacity(0.22), in: Circle())
                    }
                    .padding(.leading, 16).padding(.top, 56)
                    .accessibilityLabel("Back")
                }
                OrgCircle(org: org, size: 80)
                    .padding(5).background(Theme.ground, in: Circle())
                    .padding(.leading, 18).padding(.top, -44)

                VStack(alignment: .leading, spacing: 8) {
                    Text(org.name).font(Theme.display(32)).foregroundStyle(Theme.text)
                    let detail = [org.category, org.city].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !detail.isEmpty { Text(detail).font(Theme.body(13)).foregroundStyle(Theme.neutral700) }
                    Text("\(posts.count) \(posts.count == 1 ? "post" : "posts") · \(org.memberUids.count) \(org.memberUids.count == 1 ? "person" : "people") posting")
                        .font(Theme.body(13, .semibold)).foregroundStyle(Theme.neutral800)

                    Picker("Section", selection: $section) {
                        ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)

                    content.padding(.top, 8)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            async let loadedPosts = (try? await model.repository.posts(byAuthors: org.memberUids)) ?? []
            async let loadedPeople = (try? await model.repository.publicProfiles()) ?? []
            posts = await loadedPosts
            people = await loadedPeople.filter { org.memberUids.contains($0.uid) }
            isLoading = false
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
        } else {
            switch section {
            case .posts:
                if posts.isEmpty {
                    Text("No posts yet.").font(Theme.body(14)).foregroundStyle(Theme.neutral700).padding(.top, 16)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            NavigationLink(value: AppRoute.feedAt(posts, index)) { tile(post) }
                                .buttonStyle(PressScaleStyle(scale: 0.98))
                        }
                    }
                }
            case .people:
                VStack(spacing: 4) {
                    ForEach(people, id: \.uid) { person in
                        HStack(spacing: 12) {
                            RingAvatar(name: person.displayName, photoURL: person.photoURL, size: 44, ring: color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName.isEmpty ? "Member" : person.displayName).font(Theme.body(14.5, .bold)).foregroundStyle(Theme.text)
                                if !person.role.isEmpty { Text(person.role).font(Theme.body(12)).foregroundStyle(Theme.neutral700) }
                            }
                            Spacer()
                            let count = posts.filter { $0.authorUid == person.uid }.count
                            Text("\(count) \(count == 1 ? "post" : "posts")").font(Theme.body(12, .semibold)).foregroundStyle(Theme.neutral700)
                        }
                        .padding(.vertical, 8)
                    }
                }
            case .about:
                VStack(alignment: .leading, spacing: 10) {
                    Text(org.about.isEmpty ? "\(org.name) is on Say It." : org.about)
                        .font(Theme.body(15)).foregroundStyle(Theme.neutral800)
                    if let url = URL(string: org.website), !org.website.isEmpty {
                        Link(org.website.replacingOccurrences(of: "https://", with: ""), destination: url)
                            .font(Theme.body(14, .semibold)).foregroundStyle(Theme.accentInk)
                    }
                }
            }
        }
    }

    private func tile(_ post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            if post.isTextOnly { color } else { PostMedia(url: post.imageURL, tint: color) }
            LinearGradient(colors: [.clear, Theme.scrim.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text((post.kind?.label ?? "Post").uppercased())
                    .font(Theme.body(9.5, .bold)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 7).frame(height: 18).background(Theme.cream, in: Capsule())
                Text(post.headline).font(Theme.body(12.5, .bold)).foregroundStyle(Theme.cream).lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

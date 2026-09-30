import SwiftUI

/// Pre-sign-in onboarding, the same psychology as the other TODD apps
/// (ONBOARDING-PROFILE-BILLING-PLAYBOOK.md): the visitor writes their first
/// post - every answer preselected, so it's mostly taps - says who's
/// posting, and signs in last, which publishes it
/// (`AppModel.submitOnboardingDraftIfNeeded`). One question per screen under
/// a 4-segment bar whose first segment ("Download") is already complete.
///
/// "Already have an account?" swaps to sign-in in place, and "Just browse"
/// opens the feed signed out - reading SayIt never needs an account.
struct OnboardingWizardView: View {
    @ObservedObject var model: AppModel
    @State private var draft = OnboardingDraft.load()
    @State private var step: Step = .intent
    @State private var isShowingSignInOnly = false
    @State private var isCategoryListOpen = false
    @State private var isFinishing = false
    @State private var errorMessage = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if isShowingSignInOnly {
                    SignInView(model: model, title: "Welcome back", reason: "Sign in to pick up where you left off.", popsOnSignIn: false)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isShowingSignInOnly = false
                                } label: {
                                    Label("Back", systemImage: "chevron.left")
                                }
                            }
                        }
                } else {
                    wizard
                }
            }
            .appDestinations(model)
        }
        .onChange(of: draft) { _, newValue in newValue.save() }
    }

    // MARK: Layout

    private var wizard: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Theme.ground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
        .onChange(of: step) { _, newStep in
            // After the step's transition, so the new field exists to take focus.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isFieldFocused = newStep.isTextEntry }
            if newStep == .signIn && !draft.isReadyToSubmit {
                draft.isReadyToSubmit = true
                model.awards.recordPostDrafted()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if let previous = step.previous {
                    Button {
                        step = previous
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 32, alignment: .leading)
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
                Text("Step \(step.section.rawValue + 1) of \(Section.allCases.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 32)

            WizardProgressBar(step: step)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intent:
            Text("You're already 1 step in - the app is on your phone. Let's get your first post out there.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            question("What brings you to Say It?", hint: "You'll write your first post in under a minute.")
            VStack(spacing: 10) {
                ForEach(OnboardingDraft.Intent.allCases, id: \.self) { intent in
                    choiceRow(intent.label, isSelected: draft.intent == intent) {
                        draft.select(intent: intent)
                    }
                }
            }

        case .topic:
            question(draft.intent.topicQuestion, hint: "Pick the closest fit.")
            ChipFlowLayout(spacing: 10) {
                ForEach(draft.intent.topicOptions, id: \.self) { option in
                    chip(option, isSelected: draft.topic == option) {
                        draft.topic = option
                        draft.refreshSuggestedPost()
                        isFieldFocused = false
                    }
                }
                chip("Other", isSelected: draft.hasCustomTopic) {
                    if !draft.hasCustomTopic { draft.topic = "" }
                    isFieldFocused = true
                }
            }
            if draft.hasCustomTopic {
                textField("Describe it", text: Binding(
                    get: { draft.topic },
                    set: { draft.topic = $0; draft.refreshSuggestedPost() }
                ), contentType: nil)
            }

        case .category:
            question("Which industry?", hint: "So the right businesses see it.")
            categoryPicker

        case .post:
            question("Here's your post", hint: "We wrote it from your answers. Make it yours, or keep it.")
            TextField("Your post", text: Binding(
                get: { draft.postText },
                set: { draft.postText = $0; draft.postTextEdited = true }
            ), axis: .vertical)
            .lineLimit(3...6)
            .font(.body)
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .focused($isFieldFocused)
            .accessibilityIdentifier("wizard-post")
            HStack {
                Text("\(PostDraft.remaining(draft.postText)) characters left")
                    .foregroundStyle(PostDraft.remaining(draft.postText) < 0 ? .red : .secondary)
                Spacer()
                if draft.postTextEdited {
                    Button("Use the suggestion") {
                        draft.postTextEdited = false
                        draft.refreshSuggestedPost()
                    }
                    .fontWeight(.semibold)
                }
            }
            .font(.footnote)
            preview

        case .firstName:
            question("What's your first name?", hint: "People see who they're talking to.")
            textField("First name", text: $draft.firstName, contentType: .givenName)

        case .lastName:
            question("And your last name?", hint: nil)
            textField("Last name", text: $draft.lastName, contentType: .familyName)

        case .business:
            question("What's your business called?", hint: "Shown with your name, like \"Ada at Analytical Co\".")
            textField("Business name", text: $draft.businessName, contentType: .organizationName)

        case .layout:
            question("How should posts look?", hint: "Pick the feed you like best. You can change it anytime under Me.")
            LayoutPicker(selection: Binding(get: { draft.feedLayout }, set: { draft.feedLayout = $0; model.setFeedLayout($0) }))
            Text(draft.feedLayout.summary).font(Theme.body(14)).foregroundStyle(Theme.neutral800)

        case .signIn:
            question("Last step: sign in to post it", hint: "Your post goes live as soon as you sign in.")
            preview
            SignInButtons(model: model, isFinishing: $isFinishing, errorMessage: $errorMessage, onSignedIn: {})
                .padding(.top, 8)
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if step != .signIn {
                HStack(spacing: 12) {
                    if step.isOptional {
                        Button("Skip") { advance() }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                    Button {
                        advance()
                    } label: {
                        Text("Next")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white)
                            .background(Color.accentColor.opacity(canAdvance ? 1 : 0.4), in: Capsule())
                    }
                    .disabled(!canAdvance)
                }
            }
            HStack(spacing: 20) {
                Button("Already have an account? Sign in") { isShowingSignInOnly = true }
                Button("Just browse") { model.isBrowsingAsGuest = true }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: Pieces

    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(urlString: nil, name: previewName, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(previewName).font(.subheadline.weight(.semibold))
                    Text("now · \(PostCategory.label(for: draft.category))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(draft.postText).font(.callout)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(previewName) says \(draft.postText)")
    }

    private var previewName: String {
        draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty ? "You" : draft.displayName
    }

    /// More than five choices: a row that expands the list inline (no popup).
    @ViewBuilder
    private var categoryPicker: some View {
        Button {
            isCategoryListOpen.toggle()
        } label: {
            HStack {
                Text(PostCategory.label(for: draft.category)).font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isCategoryListOpen ? 90 : 0))
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wizard-category")

        if isCategoryListOpen {
            LazyVStack(spacing: 0) {
                ForEach(PostCategory.all, id: \.self) { category in
                    Button {
                        draft.category = category
                        draft.refreshSuggestedPost()
                        isCategoryListOpen = false
                    } label: {
                        HStack {
                            Text(PostCategory.label(for: category))
                            Spacer()
                            if category == draft.category {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func question(_ title: String, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.display(30)).foregroundStyle(Theme.text)
            if let hint {
                Text(hint).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType?) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.title3)
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .focused($isFieldFocused)
            .submitLabel(.next)
            .onSubmit { if canAdvance { advance() } }
    }

    private func chip(_ option: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark") }
                Text(option)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color(.separator)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func choiceRow(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(.body.weight(.semibold))
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(16)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Flow

    private var canAdvance: Bool {
        switch step {
        case .topic: return !draft.topic.trimmingCharacters(in: .whitespaces).isEmpty
        case .post: return PostDraft.canPost(draft.postText)
        case .firstName: return !draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .lastName: return !draft.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func advance() {
        if let next = step.next { step = next }
    }
}

// MARK: - Steps

extension OnboardingWizardView {
    /// The 4 progress segments. `.download` is never a screen - installing
    /// the app was step one.
    enum Section: Int, CaseIterable {
        case download, post, aboutYou, signIn

        var title: String {
            switch self {
            case .download: return "Download"
            case .post: return "Your post"
            case .aboutYou: return "About you"
            case .signIn: return "Sign in"
            }
        }
    }

    enum Step: Int, CaseIterable {
        case intent, topic, category, post, firstName, lastName, business, layout, signIn

        var section: Section {
            switch self {
            case .intent, .topic, .category, .post: return .post
            case .firstName, .lastName, .business, .layout: return .aboutYou
            case .signIn: return .signIn
            }
        }

        var isTextEntry: Bool { [.firstName, .lastName, .business].contains(self) }
        var isOptional: Bool { self == .business }
        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }

        /// How far through its section this screen is, 0...1.
        var sectionProgress: Double {
            let siblings = Step.allCases.filter { $0.section == section }
            guard let index = siblings.firstIndex(of: self) else { return 0 }
            return Double(index + 1) / Double(siblings.count + 1)
        }
    }
}

private struct WizardProgressBar: View {
    let step: OnboardingWizardView.Step

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(OnboardingWizardView.Section.allCases, id: \.rawValue) { section in
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.separator))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * fill(for: section))
                        }
                    }
                    .frame(height: 6)
                    HStack(spacing: 4) {
                        if fill(for: section) >= 1 {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                        }
                        Text(section.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.caption2.weight(section == step.section ? .bold : .medium))
                    .foregroundStyle(section.rawValue <= step.section.rawValue ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.section.rawValue + 1) of \(OnboardingWizardView.Section.allCases.count), \(step.section.title)")
    }

    private func fill(for section: OnboardingWizardView.Section) -> Double {
        if section.rawValue < step.section.rawValue { return 1 }
        if section == step.section { return step.sectionProgress }
        return 0
    }
}

/// Wrapping row layout for chips.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

import SwiftUI

/// What everyone agrees to when they sign in (SignInButtons says so and
/// links here). App Store guideline 1.2 requires users to accept terms that
/// make clear there is no tolerance for objectionable content or abusive users.
struct CommunityGuidelinesView: View {
    /// With a model, someone who hasn't agreed yet gets an "I Agree" button.
    var model: AppModel? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Say It is for real businesses and the people who need them. To keep it that way:")
                    .font(.body)

                rule("hand.raised", "Be respectful", "No harassment, hate, threats, or personal attacks.")
                rule("nosign", "No objectionable content", "No sexual, violent, or illegal content, and no spam or scams.")
                rule("person.crop.circle.badge.checkmark", "Be yourself", "Don't impersonate people or businesses.")
                rule("flag", "Report and block", "Report posts and comments that break these rules and block anyone abusive - both are in every post's menu, and on every comment (press and hold).")
                rule("eye.slash", "Hide what you don't want to see", "Hide Post takes a post out of your feed right away.")

                Text("There is zero tolerance for objectionable content or abusive users. Every post is screened automatically, reports are reviewed within 24 hours, and offending content is removed and its author banned.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Link("Terms of Use (EULA)", destination: AppConfig.termsURL)
                    Link("Privacy Policy", destination: AppConfig.privacyURL)
                }
                .font(.callout)

                VStack(alignment: .leading, spacing: 6) {
                    Text("See something inappropriate?").font(.headline)
                    Text("Report it from the post's menu, or contact us any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ContactSupportLink()
                }

                if let model, !model.hasAcceptedGuidelines {
                    Button {
                        model.recordGuidelinesAccepted()
                        dismiss()
                    } label: {
                        Text("I Agree")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Text("Agreeing accepts the Terms of Use (EULA) and these Community Guidelines.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            }
            .padding()
        }
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rule(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

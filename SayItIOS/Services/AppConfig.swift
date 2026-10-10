import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let webBaseURL: URL
    let backendAPIKey: String
    let masterTenantId: String

    /// Products inbox (info@taliferro.com is for consulting).
    static let supportEmail = "info@taliferro.tech"
    /// SayIt's own Terms of Use (EULA): zero tolerance for objectionable
    /// content and abusive users (App Store guideline 1.2), plus Apple's
    /// required EULA terms. Source: web-products/sayit/public/terms.html.
    static let termsURL = URL(string: "https://sayit.taliferro.tech/terms")!
    static let privacyURL = URL(string: "https://taliferro.tech/privacy")!

    static func fromBundle(bundle: Bundle = .main) -> AppConfig {
        func value(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
        }

        guard let apiBaseURL = URL(string: value("SAYIT_API_BASE_URL")), !value("SAYIT_API_BASE_URL").isEmpty,
              let webBaseURL = URL(string: value("SAYIT_WEB_BASE_URL")), !value("SAYIT_WEB_BASE_URL").isEmpty else {
            fatalError("Missing SAYIT_API_BASE_URL or SAYIT_WEB_BASE_URL in app configuration.")
        }
        let tenant = value("SAYIT_MASTER_TENANT_ID")
        guard !tenant.isEmpty else {
            fatalError("Missing SAYIT_MASTER_TENANT_ID in app configuration.")
        }

        return AppConfig(apiBaseURL: apiBaseURL, webBaseURL: webBaseURL, backendAPIKey: value("SAYIT_BACKEND_API_KEY"), masterTenantId: tenant)
    }
}

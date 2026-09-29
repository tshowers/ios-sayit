# SayIt iOS

<p align="center">
  <img src="SayItIOS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" alt="SayIt app icon" width="160">
</p>

SayIt iOS is the native iPhone app for Say It, the public board where businesses say what they need or offer. It is a SwiftUI client for the same Firestore data as https://sayit.taliferro.tech, so posts, comments, interest, and profiles are shared between the app and the web.

The app is **free**. There is no paywall and no StoreKit, and signed-out people can browse; an account is only needed to take part.

## What the app does

### Feed (browse without signing in)

- Live feed of the `posts` collection, newest first (capped at 200).
- Search across post text, author, and category, plus a category filter.
- Posts rated 4-5 by moderation are blurred behind a "Sensitive content" warning; posts rated 6 (offensive), hidden or suspended posts, and posts by people you blocked are not shown.
- Tapping a post opens it in isolation.

### Post view

- The full post, link preview or image, and its comments.
- **Share** produces `https://sayit.taliferro.tech/post/<id>`, which opens the post on the web, or in this app when it's installed (Universal Links).
- **I'm interested** writes a `post-interests` record that shows up in the author's Interest inbox (web and app).
- Comment, delete your own comments (swipe), delete your own post.
- **Report** a post (writes `post-reports` and emails info@taliferro.com) and **Block** its author.

### Taking part

Posting, commenting, sending interest, reporting and blocking each open `ParticipationGate` first: native Sign in with Apple or Google (TODDAuthKit), then a one-time acceptance of the community guidelines. After sign-in the app calls `POST /mobile/auth/bootstrap` like every TODD app so the TODD account exists; that call is best-effort and never blocks posting.

New posts go through the same AI moderation as the web (`POST /openai`, same prompt and parser), which sets `contentRating`, `ratingExplanation`, and may correct the category. If moderation fails the post still goes out unrated, as on the web.

### Interest inbox

People who tapped "I'm interested" on your posts, newest first, with an unread badge on the tab. Opening one marks it viewed and shows the post; swipe to email the person.

### Me

- **Say It profile**: display name, "what do you do or need", business details, website, tagline and intro. It saves through `POST /sayit/profile/complete` (the web's endpoint) with the web's validation rules, and makes the profile public in the directory.
- **TODD Account**: TODDProfileKit's shared profile screen, including **Delete Account** (App Store guideline 5.1.1(v)).
- Blocked people (unblock), sign out, community guidelines, terms, privacy, contact support.

## App flow

```text
SayItIOSApp            Firebase, Google Sign-In callback, Universal Links
└── RootView           Tabs + sheet for a post opened from a link
    ├── FeedView → PostDetailView → ReportView
    │   └── ComposerView
    ├── InterestInboxView → PostDetailView
    └── MyProfileView → SayItProfileEditor, ProfileView (TODDProfileKit), BlockedPeopleView
    (ParticipationGate → SignInView, CommunityGuidelinesView wherever an account is needed)
```

## Architecture

```text
AppModel            Shared state: live feed, profile, blocks, guideline acceptance, unread count, linked post
AuthService         Firebase Auth state, ID tokens, TODD account bootstrap
SayItRepository     Every Firestore read/write (same paths and fields as the web)
BackendClient       /openai moderation, /sayit/profile/complete, /send-email report alerts
FirestoreValues     Converts Firestore Timestamps to Date so models stay Firebase-free
Models/, Logic/     Plain Swift: Post, Comment, Interest, SayItProfile, FeedFilter,
                    Moderation, PostLinks, ProfileValidation, PostDraft - all unit tested
```

## Data (shared with the web app)

| Path | Read | Written by the app |
| --- | --- | --- |
| `posts` | Feed and post view (signed out too) | New posts; delete own |
| `posts/{id}/comments` | Post view | Add; delete own |
| `post-interests` | Interest inbox (`postAuthorUid == me`) | "I'm interested"; mark viewed |
| `tenants/{master}/say-it-profiles/{uid}` | Profile editor, blocks | `blockedUids` only (profile saves go through the backend) |
| `post-reports` | - | Reports (new collection, app only for now) |

The master tenant id is `SAYIT_MASTER_TENANT_ID` in `project.yml`.

## Requirements

- Xcode 27+, iOS 17.0+, XcodeGen 2.38+.
- Sibling packages `../TODDAuthKit` and `../TODDProfileKit`.
- Firebase iOS app **SayIt iOS** (`1:633736143723:ios:cc8bff3d613d9ad75fe22e`, bundle ID `tech.taliferro.sayitios`) in the `taliferrotech` project. It is already registered.

## First-time setup

1. **Firebase config.** `SayItIOS/GoogleService-Info.plist` is not committed. On a fresh checkout:

   ```bash
   firebase apps:sdkconfig IOS 1:633736143723:ios:cc8bff3d613d9ad75fe22e --project taliferrotech --out SayItIOS/GoogleService-Info.plist
   ```

   The Google Sign-In callback scheme in `project.yml` (`CFBundleURLTypes`) is this plist's `REVERSED_CLIENT_ID`.

2. **Apple Developer portal.** Create the App ID `tech.taliferro.sayitios` (team `6377FLHLAG`) with **Sign in with Apple** and **Associated Domains** enabled.

3. **App Store Connect.** Create the SayIt app record for that bundle ID. Free, no in-app purchases.

4. **Generate and run:**

   ```bash
   xcodegen generate
   open SayItIOS.xcodeproj
   ```

   Debug builds also show TODDAuthKit's email/password sign-in for Simulator testing before Sign in with Apple is provisioned.

## Configuration

Defined in `project.yml` and copied into `Generated/Info.plist`. Edit `project.yml` and re-run `xcodegen generate`; never edit the generated plist.

| Key | Value | Purpose |
| --- | --- | --- |
| `PRODUCT_BUNDLE_IDENTIFIER` | `tech.taliferro.sayitios` | App identifier |
| `SAYIT_API_BASE_URL` | `https://api.taliferro.tech/api` | TODD backend |
| `SAYIT_WEB_BASE_URL` | `https://sayit.taliferro.tech` | Share links |
| `SAYIT_BACKEND_API_KEY` | web `environment.apiKey` | Header for `/openai` moderation, as on the web |
| `SAYIT_MASTER_TENANT_ID` | Taliferro master tenant | Where SayIt profiles live |

## Universal Links

`applinks:sayit.taliferro.tech` is declared in the entitlements, and `web-products/sayit/public/.well-known/apple-app-site-association` lists `6377FLHLAG.tech.taliferro.sayitios` for `/post/*`. The file goes live with the next web deploy (`npm run deploy:hosting` in `web-products/sayit`). Old `/?post=<id>` links are understood too.

## Tests

```bash
xcodebuild test -project SayItIOS.xcodeproj -scheme SayItIOS -destination 'platform=iOS Simulator,name=iPhone 17'
```

- `SayItIOSTests`: unit tests for everything in `Models/` and `Logic/`. They compile those folders directly (no host app), so they also run from the `SayItIOSTests` scheme without Firebase.
- `SayItIOSUITests`: signed-out smoke tests against the live feed (browse, open a post, sign-in prompts). They only read.

## App Store review notes (user-generated content, guideline 1.2)

The app has what Apple requires: automatic moderation, guideline acceptance before posting, Report and Block on every post, and a support contact. The guidelines promise **reports are acted on within 24 hours**. Each report emails info@taliferro.com and is stored in `post-reports`, but removal is manual (set `hidden: true` on the post, or delete it), so someone has to watch that inbox.

## Not in v1

Business directory and business pages, Newsstand, image uploads in posts, push notifications for new interest. The web app still has all of these except push.

# SayIt iOS

<p align="center">
  <img src="SayItIOS/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" alt="SayIt app icon" width="160">
</p>

SayIt iOS is the native iPhone app for Say It, the public board where businesses say what they need or offer. It is a SwiftUI client for the same Firestore data as https://sayit.taliferro.tech, so posts, comments, interest, and profiles are shared between the app and the web.

The app is **free**. There is no paywall and no StoreKit, and signed-out people can browse; an account is only needed to take part.

## Design

The UI follows the Claude Design handoff (`corporate/design_handoff_sayit_post_feed`): the "Organic" system (cream #f5ead8, terracotta #b2622d, sage), with **Caprasimo** for display type and **Figtree** for body text. Both fonts are bundled under the SIL Open Font License, and the tokens live in `Features/Shared/Theme.swift`.

- **Feed** (`FeedPagerView`): one full-screen post at a time. Swiping left or right past 60pt pages; anything shorter snaps back, and the first and last posts rubber-band. There are three layouts:
  - **1a Overlay:** text over the photo with a side rail.
  - **1b Card:** a floating card over the photo, topped with an org stripe.
  - **1c Ribbon:** the org name down a side ribbon, a price sticker, and a big round "I'm interested" button.

  Posts without a photo become quote cards. Each post also has a ••• button for comments, Report and Block, which the design didn't include.
- **Post stage** (`PostStage`, all three layouts):
  - A post's photo fills the top 60% of the screen and fades into the stage: black in dark mode, the cream ground in light. The photo is never hidden behind the post.
  - iPad portrait: the post starts halfway down. iPhone: the post's bottom sits 20% up from the bottom and grows upward. iPad landscape: photo on the left, post on the right.
  - Posts without a photo get an org-colored band behind the top bar instead of an empty photo area.
  - The whole post always shows, and it scrolls if it's taller than its space.
- **Every post follows the prototypes:** the photo area, or the design's striped placeholder in the org's tone when there's no photo, with the headline, caption, category and **AI summary** (moderation's `ratingExplanation`, the web's "Content Description").
- **Light and dark:** every screen follows the system appearance. `Theme` pairs each handoff color with a dark counterpart from the same warm ramp.
- **Sizing:** type and controls scale with the device (`Theme.scale`, up to 1.35× on iPad), and each post's content sits in a 600pt column on wide screens.
- **Layout choice:** picked in onboarding ("How should posts look?") and changeable under Me → Feed layout. It's stored as `feedLayout` on the SayIt profile. Every like, "I'm interested" and message also writes `sayit-layout-events {uid, layout, action, postId}`, so the winning layout can be chosen from real engagement.
- **Top bar:** SayIt wordmark, For you / Orgs / Inbox, search, compose (+), and your avatar for Me. There's no bottom tab bar. The bar tightens on narrow phones rather than overflowing.
- **Search** (`SearchView`):
  - Every word must match, in any order, across the post text, headline, caption, author, org, job title, category and price.
  - Chips filter by Selling / Looking for and by the industries in the feed.
  - Tapping a result opens the full-screen feed there, so you can swipe through the rest of the results.
  - It covers the posts the feed has loaded (the newest 200).
- **Inbox** (`InboxView`, `ThreadView`):
  - "I'm interested" creates or reopens `sayit-threads/{postId}_{interestedUid}`, a one-on-one conversation with the author about that post.
  - Filters: All / I'm interested / In my posts. Unread badges.
  - The thread screen has the post pinned at the top, quick replies and a composer.
  - The other person gets an email on their first unread message (`/send-email`).
  - Turning interest off keeps the conversation.
  - Interest without a thread (older, or sent from the web) is listed and becomes a thread on the author's first reply.
- **Orgs** (`OrgsView`, `OrgProfileView`): built from public SayIt profiles that share a business name (`OrgDirectory`), with a stable color per org. There's no follow and no "verified", since verification doesn't exist yet. Org profiles have Posts, People and About; tapping a post opens it in the full-screen pager.
- **Posts** now have an optional title, caption, kind (`selling` / `looking-for`), price, photo (Firebase Storage `sayit/posts/{uid}/…`), `authorRole` and `orgName`. `content` is still written, so the web keeps showing new posts.
- **Likes:** `favoriteUserIds` / `favoriteCount` on the post plus `favoritePostIds` on the profile, the same fields the web uses.
- **Firestore rules** for threads, messages, reports and layout events live in `taliferrotech/frontend/firestore.rules`. Only a thread's two participants can read its messages.

## What the app does

### First launch: the wizard (sign in last)

Signed-out, the app opens on `OnboardingWizardView` (ONBOARDING-PROFILE-BILLING-PLAYBOOK.md). The person writes their first post before signing in:

- A 4-segment progress bar. "Download" is already complete.
- Looking for or offering, then what, then which industry. Each has a default preselected, and industry is a list that expands inline.
- The post, pre-written from those answers and editable, with a live preview.
- First and last name (required), then business (skippable).
- Feed layout: 1a, 1b or 1c, shown as mini previews.
- Sign in with Apple or Google. Signing in publishes the post (`AppModel.submitOnboardingDraftIfNeeded`):
  1. Fill blank TODD profile fields (`/onboarding/profile`).
  2. Complete the SayIt profile, unless it's already complete.
  3. Publish the post with moderation, then open it.

The draft is kept in `UserDefaults` and each finished step is recorded, so a failure retries on the next launch without repeating anything. "Already have an account? Sign in" swaps to sign-in in place. "Just browse" opens the feed signed out, because reading SayIt never needs an account (App Store guideline 5.1.1). A shared post link also skips the wizard.

### Awards

`TODDAwardsKit`, backend product `sayit`, synced across devices:

- The Opener: wrote a post in the wizard.
- On the Record: first post.
- Open for Business: profile complete.
- The Connector: sent interest.
- The Conversationalist: first comment.
- Wanted: 1 person interested.
- In Demand: 5 people interested.
- The Regular: posts on 3 different days.
- The Legend (hidden): 25 posts.

Post and interest awards are computed from Firestore data (`SayItAwardRules`). Celebrations use `AwardUnlockView`; the grid is a pushed page from Me.

### No popups

Every page pushes (`AppRoute` / `AppDestination`): sign-in, composer, report, guidelines, profile, account, awards. Signing in is also agreeing to the community guidelines; the sign-in page says so and links to them. Only system confirmations (delete, block) and the award celebration are modal.

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

Signed out, commenting, sending interest, reporting and blocking push the sign-in page (native Apple/Google via TODDAuthKit), and New Post goes back to the wizard. After sign-in the app calls `POST /mobile/auth/bootstrap` like every TODD app so the TODD account exists; that call is best-effort and never blocks posting.

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
- Sibling packages `../TODDAuthKit`, `../TODDProfileKit` and `../TODDAwardsKit`.
- Backend: `sayit` in `AWARD_PRODUCTS` (`todd-backend/functions/awards.service.js`). Until that's deployed, awards celebrate on the device and sync later.
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
- `SayItIOSUITests`: signed-out smoke tests against the live feed. They cover the wizard from defaults to its sign-in step, "Just browse", opening a post, and account-only actions pushing sign-in. They only read. The Debug-only launch argument `-uiTestFreshInstall` resets to first launch.

## App Store review notes (user-generated content, guideline 1.2)

The app has what Apple requires: automatic moderation, guideline acceptance before posting, Report and Block on every post, and a support contact. The guidelines promise **reports are acted on within 24 hours**. Each report emails info@taliferro.com and is stored in `post-reports`, but removal is manual (set `hidden: true` on the post, or delete it), so someone has to watch that inbox.

## Not in v1

Business directory and business pages, Newsstand, image uploads in posts, push notifications for new interest. The web app still has all of these except push.

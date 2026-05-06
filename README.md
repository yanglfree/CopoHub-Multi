# CopoHub

A feature-rich GitHub client built with **Flutter**, targeting **HarmonyOS** and **iOS**. CopoHub brings a polished mobile experience for browsing repositories, tracking trends, reading daily reports, and managing your GitHub profile — all from your phone.

## ✨ Features

### Core
- **GitHub OAuth login** — authenticate via standard OAuth flow or Personal Access Token (PAT)
- **Dashboard** — 5-tab bottom navigation: Home, Discover, Featured, Notifications, Profile
- **Repository browser** — README preview, code tree, issues, commits, releases, branch/tag switching
- **Search** — global repository & user search
- **Notifications** — GitHub notification inbox with read/unread management

### Discovery
- **Trending** — daily/weekly/monthly trending repos with language filter
- **Featured** — algorithm-curated and manually-picked repository recommendations
- **Daily report** — AI-generated daily GitHub trend analysis (zh/en) with **QR-coded share cards**
- **Repo analysis** — AI-powered repository breakdown (tech stack, architecture, pros/cons)

### Social
- **User profile** — contribution heatmap (8 theme colors), pinned/top repos, organizations, followers/following
- **Follow/unfollow**, **star/unstar** — with optimistic UI and memory cache
- **Share** — repository & profile sharing via native share sheet and custom image cards

### Pro Membership
- Subscription management with monthly/yearly/lifetime plans
- Glassmorphism membership UI with Bento Grid layout

### Utilities
- **Clipboard detector** — auto-detects GitHub repo URLs from clipboard and offers quick navigation
- **In-app update** — checks backend for new versions and prompts upgrade
- **Create repository** — create new GitHub repos directly from the app
- **File viewer** — inline code viewer with syntax highlighting
- **Commit diff viewer** — per-file diff detail with additions/deletions
- **Sensitive content filter** — client-side content filtering for safety and compliance
- **Privacy & Feedback** — built-in feedback system and policy viewers
- **Dark mode** — full dark/light theme support with system-follow option
- **i18n** — Chinese (zh) and English (en) localization

## 🏗 Architecture

```
flutter/lib/
├── api/                    # Network layer
│   ├── github_api_client   #   GitHub REST & GraphQL (dio, ETag cache, dedup)
│   ├── daily_api_client    #   Trending / daily report / repo analysis
│   ├── copohub_api_client  #   Featured curated list
│   ├── api_cache           #   Hive-backed disk + memory cache
│   └── api_response        #   Unified result type
├── models/                 # Data models (User, Repository, Issue, Commit, …)
├── pages/                  # 21 page modules
│   ├── dashboard/          #   Home feed
│   ├── discover/           #   Trending explorer
│   ├── featured/           #   Curated picks
│   ├── daily/              #   Daily AI report
│   ├── repository/         #   Repo detail (5 sub-tabs)
│   ├── search/             #   Global search
│   ├── login/              #   OAuth & PAT login
│   ├── member/             #   Pro membership gate
│   └── …                   #   commit, issue, file_viewer, profile, settings, etc.
├── services/               # Business logic singletons
│   ├── auth_service        #   Login state machine
│   ├── pro_member_service  #   Subscription state
│   ├── contribution_service#   Heatmap data
│   ├── clipboard_detector  #   GitHub URL detection
│   ├── app_update_service  #   Version check
│   ├── share_service       #   Native share
│   ├── theme_service       #   Theme persistence
│   └── sensitive_content_filter
├── providers/              # Riverpod state (auth, theme)
├── router/                 # GoRouter (auth-guard, tab shell)
├── components/             # Shared UI (markdown, skeleton, dialogs, …)
├── theme/                  # Material 3 light/dark theme (GitHub-style palette)
├── l10n/                   # Localization delegate (zh, en)
└── utils/                  # Constants, error messages, platform checks
```

### Key Libraries

| Category | Library |
|---|---|
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| HTTP | `dio` |
| Local storage | `shared_preferences`, `hive` |
| Markdown | `flutter_markdown`, `flutter_highlight` |
| Image | `cached_network_image` |
| WebView (OAuth) | `webview_flutter` |
| i18n | `intl`, `flutter_localizations` |
| Utilities | `url_launcher`, `share_plus`, `path_provider` |

## 📱 Supported Platforms

| Platform | SDK | Status |
|---|---|---|
| **HarmonyOS** | HarmonyOS NEXT (API 15, SDK 5.0.3) | ✅ Primary |
| **iOS** | iOS 12+ | ✅ Supported |
| **Android** | API 21+ | 🔧 Build-ready |

> The codebase is designed for **dual-toolchain** compatibility: upstream Flutter (iOS/Android) and Flutter-OH (HarmonyOS). Shared Dart code avoids APIs that only exist in one toolchain. See `AGENTS.md` for the compatibility rules.

### HarmonyOS-Specific

The `flutter/ohos/` directory contains:
- **entry module** — `EntryAbility.ets` (app lifecycle), native ArkTS pages
- **Platform plugins** — `CopoHubClipboardPlugin`, `SharedPreferencesPlugin`, `PathProviderPlugin`
- **HAR** — pre-built Flutter engine for HarmonyOS (`flutter.har`)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.4.0 <4.0.0`
- For HarmonyOS: DevEco Studio with Flutter-OH toolchain
- For iOS: Xcode 15+
- GitHub OAuth App credentials (already configured in `constants.dart`)

### Build & Run

```bash
# Clone
git clone https://github.com/yanglfree/CopoHub-Multi.git
cd CopoHub-Multi/flutter

# Install dependencies
flutter pub get

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android
```

#### HarmonyOS

```bash
cd flutter/ohos

# Copy and configure the signing profile
cp build-profile.example.json5 build-profile.json5
# Edit build-profile.json5 with your signing certificates

# Build HAP
hvigorw assembleHap
```

## 🔧 Configuration

| Item | Location |
|---|---|
| GitHub OAuth credentials | `lib/utils/constants.dart` |
| API base URLs | `lib/utils/constants.dart` |
| HarmonyOS signing | `ohos/build-profile.json5` |
| App version | `pubspec.yaml` → `version` |

## 📚 Documentation

Detailed documentation, design documents, and project walkthroughs are located in the [docs/](./docs) directory. For AI agent specific rules and compatibility guidelines, refer to [AGENTS.md](./AGENTS.md).

## 📄 License

This project is proprietary. All rights reserved.

## 📬 Contact

- Email: youdroid2048@gmail.com

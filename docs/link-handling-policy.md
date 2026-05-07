# README Link Handling Policy

This document defines how CopoHub handles hyperlinks tapped inside rendered
README content. The goal is to keep navigation contextual: links that point to
resources the app can render natively open in-app, while everything else opens
in the system browser or mail client.

---

## Link Classification

All links are first resolved to an absolute URL by `_resolveReadmeUrl` in
`repository_page.dart`. The resolved URL is then classified and dispatched by
`resolveLinkAction` in `lib/utils/link_utils.dart`.

| Link type | Resolved form | Behavior |
|---|---|---|
| **Email address** | `mailto:user@example.com` | Opens the system mail app |
| **GitHub user profile** | `https://github.com/username` (exactly 1 path segment, non-reserved) | Opens the user profile page in-app |
| **GitHub repository root** | `https://github.com/owner/repo` (exactly 2 path segments) | Opens the repository detail page in-app |
| **GitHub source file** | `https://github.com/owner/repo/blob/<branch>/<path>` | Opens the in-app file viewer |
| **GitHub issue** | `https://github.com/owner/repo/issues/<number>` | Opens the in-app issue detail page |
| **Other GitHub URLs** | `github.com/...` (e.g. pull requests, directory trees, releases, tags, reserved paths like `/explore`) | Opens in the system browser |
| **Third-party links** | Any `http`/`https` URL on a non-GitHub host | Opens in the system browser |
| **Anchor links** | `#section` — resolved to the full GitHub HTML URL | Opens in the system browser (in-page scroll is not supported) |

---

## URL Resolution

Before classification, relative and protocol-relative URLs are expanded to
absolute form using context from the README being displayed:

- **Absolute URL** (`http://`, `https://`, `mailto:`) — used as-is.
- **Protocol-relative** (`//example.com`) — prepended with `https:`.
- **Anchor-only** (`#section`) — prepended with the README's `html_url`
  (e.g. `https://github.com/owner/repo/blob/main/README.md`).
- **Root-relative** (`/path/to/file`) — resolved against `github.com`.
- **Relative path** (`docs/file.md`) — resolved relative to the directory
  containing the README file, then converted to an absolute GitHub URL.

The resolution logic lives in `_resolveReadmeUrl` inside `_ReadmeTabState`.

---

## HTML Preprocessing

READMEs may embed raw HTML (e.g. `<a href="...">`) before the Markdown
renderer sees them. The `_stripHtmlForMarkdown` pre-processor converts HTML
`<a>` tags to Markdown `[text](href)` links. Both the link text **and the
href** are HTML-entity-unescaped (e.g. `&amp;` → `&`) to prevent malformed
URLs from reaching the tap handler.

---

## Implementation

| Concern | Location |
|---|---|
| Link action types & classification | `lib/utils/link_utils.dart` — `LinkAction`, `resolveLinkAction()` |
| Link dispatch (routing / launch) | `lib/utils/link_utils.dart` — `dispatchLinkAction()` |
| URL resolution from relative links | `lib/pages/repository/repository_page.dart` — `_resolveReadmeUrl()` |
| HTML → Markdown pre-processing | `lib/pages/repository/repository_page.dart` — `_stripHtmlForMarkdown()` |
| Tap handler entry point | `lib/pages/repository/repository_page.dart` — `onTapLink` in `buildMarkdown` |

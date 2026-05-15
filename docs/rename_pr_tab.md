# Renaming Pull Request Tab to PR

## Changes
The user requested to rename the "Pull Request" tab on the home page to "PR". Since the project supports multi-language localization through a hand-written `AppLocalizations` class, I modified the relevant strings in `lib/l10n/app_localizations.dart`.

### Modified Files
- `lib/l10n/app_localizations.dart`:
    - Updated `myPullRequests` to "PR".
    - Updated `noPullRequests` to "暂无 PR" (zh) and "No PRs" (en).

## Verification
- Checked `lib/pages/dashboard/home_page.dart` to confirm it uses `l10n.myPullRequests` for the tab title.
- Ran `flutter analyze` to ensure no syntax errors were introduced.

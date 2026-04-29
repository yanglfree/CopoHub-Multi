import 'package:flutter/material.dart';

/// Hand-written localization class — supports 'en' and 'zh'.
/// Add strings here as the app grows; run flutter gen-l10n if migrating to ARB.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get _zh => locale.languageCode == 'zh';

  // ── Repository page tabs ──────────────────────────────────────────────────
  String get tabReadme => 'README';
  String get tabCode => _zh ? '代码' : 'Code';
  String get tabIssues => _zh ? '问题' : 'Issues';
  String get tabCommits => _zh ? '提交' : 'Commits';
  String get tabReleases => _zh ? '发布' : 'Releases';

  // ── Issues filter ─────────────────────────────────────────────────────────
  String get filterAll => _zh ? '全部' : 'All';
  String get filterOpen => _zh ? '开放' : 'Open';
  String get filterClosed => _zh ? '已关闭' : 'Closed';

  // ── Empty & error states ──────────────────────────────────────────────────
  String get noReadme => _zh ? '暂无 README' : 'No README';
  String get noIssues => _zh ? '暂无 Issues' : 'No Issues';
  String get noReleases => _zh ? '暂无 Release' : 'No Releases';
  String get noCommits => _zh ? '暂无提交' : 'No commits';
  String get noFiles => _zh ? '暂无文件' : 'No files';
  String get loadFailed => _zh ? '加载失败' : 'Load failed';
  String get retry => _zh ? '重试' : 'Retry';

  // ── Branch ────────────────────────────────────────────────────────────────
  String get branch => _zh ? '分支' : 'Branch';
  String get selectBranch => _zh ? '选择分支' : 'Select branch';
  String get branchesAndTags => _zh ? '分支与标签' : 'Branches & Tags';

  // ── Code tab ──────────────────────────────────────────────────────────────
  String get root => _zh ? '根目录' : 'Root';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

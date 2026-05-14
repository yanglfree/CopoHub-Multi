import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dialogs/app_dialog.dart';
import '../markdown/markdown_scroll_fix.dart';
import '../../utils/constants.dart';

class DailyReportSections {
  const DailyReportSections({
    required this.title,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String introduction;
  final List<DailyReportSection> sections;
}

class DailyReportSection {
  const DailyReportSection({
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;
}

class DailyReportRepositoryRef {
  const DailyReportRepositoryRef({
    required this.owner,
    required this.name,
  });

  final String owner;
  final String name;

  String get fullName => '$owner/$name';
  String get reportLink => 'copohub://repository/$owner/$name';
  String get route => '/repository/$owner/$name';
}

DailyReportSections parseDailyReportSections(String markdown) {
  final lines = markdown.trim().split('\n');
  String title = '';
  final introduction = <String>[];
  final sections = <DailyReportSection>[];
  String? currentSectionTitle;
  final currentSectionLines = <String>[];

  void flushSection() {
    final sectionTitle = currentSectionTitle;
    if (sectionTitle == null) return;
    sections.add(DailyReportSection(
      title: sectionTitle,
      markdown: currentSectionLines.join('\n').trim(),
    ));
    currentSectionLines.clear();
  }

  for (final line in lines) {
    if (line.startsWith('# ') && title.isEmpty) {
      title = line.substring(2).trim();
      continue;
    }

    if (line.startsWith('## ')) {
      flushSection();
      currentSectionTitle = line.substring(3).trim();
      continue;
    }

    if (currentSectionTitle == null) {
      introduction.add(line);
    } else {
      currentSectionLines.add(line);
    }
  }

  flushSection();

  return DailyReportSections(
    title: title,
    introduction: introduction.join('\n').trim(),
    sections: sections,
  );
}

String formatDailyReportDateLabel(
  String value, {
  DateTime? now,
  String todayLabel = '今天',
}) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final normalized = _formatDate(value);
  final current = now ?? DateTime.now();
  final isToday = date.year == current.year &&
      date.month == current.month &&
      date.day == current.day;
  return isToday ? '$todayLabel ($normalized)' : normalized;
}

List<DailyReportRepositoryRef> extractDailyReportRepositoryRefs(
  String markdown, {
  Iterable<Map<String, dynamic>> repositories = const [],
}) {
  final refs = <String, DailyReportRepositoryRef>{};

  void add(String owner, String name) {
    final normalizedName = _stripTrailingRepositoryPunctuation(name);
    if (!_isValidRepositoryPart(owner) ||
        !_isValidRepositoryPart(normalizedName)) {
      return;
    }
    final ref = DailyReportRepositoryRef(owner: owner, name: normalizedName);
    refs.putIfAbsent(ref.fullName, () => ref);
  }

  final fullNamePattern = RegExp(
    r'(?:^|[^\w.-])([A-Za-z0-9][A-Za-z0-9-]*)/([A-Za-z0-9._-]+)(?=$|[^\w.-])',
    multiLine: true,
  );
  for (final match in fullNamePattern.allMatches(markdown)) {
    add(match.group(1)!, match.group(2)!);
  }

  final headingPattern = RegExp(
    r'^###\s+\d+\.\s+\*\*([^*\n]+)\*\*[（(]([^）)\n]+)[）)]',
    multiLine: true,
  );
  for (final match in headingPattern.allMatches(markdown)) {
    add(match.group(2)!.trim(), match.group(1)!.trim());
  }

  for (final repository in repositories) {
    final ref = repositoryRefFromData(repository);
    if (ref != null) add(ref.owner, ref.name);
  }

  // Build a name-to-owner lookup from already extracted refs so we can
  // resolve heading-only repo names that lack explicit owner info.
  final nameToOwner = <String, String>{};
  for (final ref in refs.values) {
    nameToOwner.putIfAbsent(ref.name, () => ref.owner);
  }

  // h3 heading with leading number but NO bold:
  // e.g. ### 1. financial-services (Python) | ⭐ +1,367 | Python
  final h3NumberedNamePattern = RegExp(
    r'^###\s+\d+\.\s+([A-Za-z0-9][A-Za-z0-9._-]*)(?=\s|[（(|：:]|$)',
    multiLine: true,
  );
  for (final match in h3NumberedNamePattern.allMatches(markdown)) {
    final name = _stripTrailingRepositoryPunctuation(match.group(1)!.trim());
    final owner = nameToOwner[name];
    if (owner != null) add(owner, name);
  }

  // h3 heading without number, repo name followed by colon or Chinese colon:
  // e.g. ### PageIndex：Vectorless RAG架构的革命性尝试
  // e.g. ### goose：Rust语言的AI代理新范式
  final h3ColonNamePattern = RegExp(
    r'^###\s+([A-Za-z0-9][A-Za-z0-9._-]*)[：:]',
    multiLine: true,
  );
  for (final match in h3ColonNamePattern.allMatches(markdown)) {
    final name = _stripTrailingRepositoryPunctuation(match.group(1)!.trim());
    final owner = nameToOwner[name];
    if (owner != null) add(owner, name);
  }

  return refs.values.toList();
}

String linkifyDailyReportRepositories(
  String markdown,
  Iterable<DailyReportRepositoryRef> refs,
) {
  var linked = markdown;
  final sortedRefs = refs.toList()
    ..sort((a, b) => b.fullName.length.compareTo(a.fullName.length));
  final uniqueNameRefs = _uniqueRepositoryNameRefs(sortedRefs);

  for (final ref in sortedRefs) {
    final owner = RegExp.escape(ref.owner);
    final name = RegExp.escape(ref.name);
    final headingPattern =
        RegExp(r'\*\*(' + name + r')\*\*([（(])(' + owner + r')([）)])');
    linked = linked.replaceAllMapped(headingPattern, (match) {
      final repoName = match.group(1)!;
      return '**[$repoName](${ref.reportLink})**${match.group(2)}${match.group(3)}${match.group(4)}';
    });

    final fullCodeSpanPattern = RegExp('`(${RegExp.escape(ref.fullName)})`');
    linked = linked.replaceAllMapped(fullCodeSpanPattern, (match) {
      final fullName = match.group(1)!;
      return '[`$fullName`](${ref.reportLink})';
    });

    final fullNamePattern = RegExp(
      r'(^|[^`\[\]\w./:-])(' + RegExp.escape(ref.fullName) + r')(?=$|[^`\w/:-])',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(fullNamePattern, (match) {
      final prefix = match.group(1)!;
      final fullName = match.group(2)!;
      return '$prefix[$fullName](${ref.reportLink})';
    });
  }

  for (final ref in uniqueNameRefs) {
    final boldNameWithSuffixPattern = RegExp(
      r'\*\*(' + RegExp.escape(ref.name) + r')([（(][^）)\n]+[）)])\*\*',
    );
    linked = linked.replaceAllMapped(boldNameWithSuffixPattern, (match) {
      final name = match.group(1)!;
      final suffix = match.group(2)!;
      return '**[$name](${ref.reportLink})$suffix**';
    });

    final codeSpanPattern = RegExp('`(${RegExp.escape(ref.name)})`');
    linked = linked.replaceAllMapped(codeSpanPattern, (match) {
      final name = match.group(1)!;
      return '[`$name`](${ref.reportLink})';
    });

    // h3 heading with leading number: ### 1. RepoName ...
    // e.g. ### 1. financial-services (Python) | ⭐ +1,367
    final h3NumberedPattern = RegExp(
      r'^(###[ \t]+\d+\.[ \t]+)(' + RegExp.escape(ref.name) + r')(?!\w)',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(h3NumberedPattern, (match) {
      return '${match.group(1)!}[${match.group(2)!}](${ref.reportLink})';
    });

    // h3 heading without number: ### RepoName ...
    // e.g. ### PageIndex：Vectorless RAG架构的革命性尝试
    final h3PlainPattern = RegExp(
      r'^(###[ \t]+)(' + RegExp.escape(ref.name) + r')(?!\w)',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(h3PlainPattern, (match) {
      return '${match.group(1)!}[${match.group(2)!}](${ref.reportLink})';
    });
  }

  return linked;
}

String? repositoryRouteFromLink(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null) return null;

  if (uri.scheme == 'copohub' && uri.host == 'repository') {
    final segments = uri.pathSegments;
    if (segments.length >= 2) {
      return '/repository/${segments[0]}/${segments[1]}';
    }
  }

  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'github.com' &&
      uri.pathSegments.length >= 2) {
    return '/repository/${uri.pathSegments[0]}/${uri.pathSegments[1]}';
  }

  return null;
}

DailyReportRepositoryRef? repositoryRefFromData(Map<String, dynamic> data) {
  final fullName = data['full_name'] as String?;
  if (fullName != null && fullName.contains('/')) {
    final parts = fullName.split('/');
    if (parts.length >= 2) {
      return DailyReportRepositoryRef(owner: parts[0], name: parts[1]);
    }
  }

  final ownerValue = data['owner'];
  final owner = ownerValue is Map<String, dynamic>
      ? ownerValue['login'] as String?
      : ownerValue as String?;
  final name = data['name'] as String? ?? data['repo'] as String?;
  if (owner == null || name == null) return null;
  if (!_isValidRepositoryPart(owner) || !_isValidRepositoryPart(name)) {
    return null;
  }
  return DailyReportRepositoryRef(owner: owner, name: name);
}

Map<String, dynamic> dailyReportWithRepositoryData(
  Map<String, dynamic> report,
  Iterable<Map<String, dynamic>> repositories,
) {
  final existingRepositories = report['top_repositories'] as List<dynamic>?;
  if (existingRepositories != null && existingRepositories.isNotEmpty) {
    return report;
  }

  final repositoryList = repositories.toList();
  if (repositoryList.isEmpty) return report;

  return {
    ...report,
    'top_repositories': repositoryList,
  };
}

class DailyReportView extends StatelessWidget {
  const DailyReportView({super.key, required this.report, this.onShare});

  final Map<String, dynamic> report;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final summary = report['summary'] as String? ?? '';
    final topics = (report['topics'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    final langSummaries =
        (report['language_summaries'] as Map<String, dynamic>? ?? {})
            .entries
            .toList();
    final topRepos = (report['top_repositories'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    // Parse sections from the ORIGINAL markdown first, so section titles
    // don't end up with raw "[owner/name](copohub://...)" link syntax.
    final sections = parseDailyReportSections(summary);
    final repoRefs = extractDailyReportRepositoryRefs(
      summary,
      repositories: topRepos,
    );
    // Linkify each piece of content separately so navigation works everywhere.
    final linkedIntroduction =
        linkifyDailyReportRepositories(sections.introduction, repoRefs);
    final linkedSections = sections.sections
        .map((s) => DailyReportSection(
              title: s.title,
              markdown: linkifyDailyReportRepositories(s.markdown, repoRefs),
            ))
        .toList();
    final linkedSummary = linkifyDailyReportRepositories(summary, repoRefs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _ReportHeader(
          title: sections.title.isEmpty ? 'GitHub Trending 日报' : sections.title,
          date: report['date'] as String?,
          language: report['language'] as String?,
          updatedAt: report['updated_at'] as String?,
          topics: topics,
          onShare: onShare,
        ),
        if (linkedIntroduction.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ArticleLead(markdown: linkedIntroduction),
        ],
        if (langSummaries.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle(icon: Icons.auto_graph, title: '语言动态'),
          const SizedBox(height: 10),
          _LanguageSummaryRail(entries: langSummaries),
        ],
        if (topRepos.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle(icon: Icons.star_border, title: '精选仓库'),
          const SizedBox(height: 10),
          _TopRepoRail(repos: topRepos.take(5).toList()),
        ],
        if (linkedSections.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (var i = 0; i < linkedSections.length; i++) ...[
            _ArticleSection(
              index: i + 1,
              section: linkedSections[i],
            ),
            if (i != linkedSections.length - 1) const SizedBox(height: 14),
          ],
        ] else if (summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ReportMarkdown(markdown: linkedSummary),
        ],
      ],
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.title,
    required this.date,
    required this.language,
    required this.updatedAt,
    required this.topics,
    this.onShare,
  });

  final String title;
  final String? date;
  final String? language;
  final String? updatedAt;
  final List<String> topics;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleTopics = topics.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.insights, size: 19, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily Report',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (language != null && language!.isNotEmpty)
                _MetaPill(label: language!.toUpperCase()),
              if (onShare != null) ...[                const SizedBox(width: 6),
                InkWell(
                  onTap: onShare,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.ios_share_outlined,
                        size: 18, color: cs.primary),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              _InfoIconButton(
                color: cs.primary,
                onTap: () => _showReportInfoDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (date != null)
                _MetaPill(label: formatDailyReportDateLabel(date!)),
              if (updatedAt != null)
                _MetaPill(label: '更新 ${_formatDate(updatedAt!)}'),
            ],
          ),
          if (visibleTopics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleTopics
                  .map((topic) => _TopicChip(label: topic))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArticleLead extends StatelessWidget {
  const _ArticleLead({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withAlpha(95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.secondary.withAlpha(120)),
      ),
      child: _ReportMarkdown(markdown: markdown),
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({
    required this.index,
    required this.section,
  });

  final int index;
  final DailyReportSection section;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                ),
              ),
            ],
          ),
          if (section.markdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ReportMarkdown(markdown: section.markdown),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _ReportMarkdown extends StatelessWidget {
  const _ReportMarkdown({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    return MarkdownScrollFix(
      child: MarkdownBody(
        data: markdown,
        styleSheet: _markdownStyle(context),
        onTapLink: (text, href, title) {
          if (href == null) return;
          final route = repositoryRouteFromLink(href);
          if (route != null) {
            context.push(route);
            return;
          }
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}

class _LanguageSummaryRail extends StatelessWidget {
  const _LanguageSummaryRail({required this.entries});

  final List<MapEntry<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return SizedBox(
            width: 224,
            child: _LanguageSummaryCard(
              language: entry.key,
              summary: entry.value as String? ?? '',
            ),
          );
        },
      ),
    );
  }
}

class _LanguageSummaryCard extends StatelessWidget {
  const _LanguageSummaryCard({
    required this.language,
    required this.summary,
  });

  final String language;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _languageColor(language);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.38,
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRepoRail extends StatelessWidget {
  const _TopRepoRail({required this.repos});
  final List<Map<String, dynamic>> repos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: repos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(
          width: 260,
          child: _TopRepoTile(data: repos[index]),
        ),
      ),
    );
  }
}

class _TopRepoTile extends StatelessWidget {
  const _TopRepoTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ref = repositoryRefFromData(data);
    final owner = ref?.owner ?? '';
    final name = ref?.name ?? '';
    final description = data['description'] as String? ?? '';
    final stars = data['stars'] as int? ?? 0;
    final language = data['language'] as String? ?? '';

    return InkWell(
      onTap: ref == null ? null : () => context.push(ref.route),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$owner/$name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (ref != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new, size: 15, color: cs.primary),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (language.isNotEmpty) ...[
                  _LanguageBadge(language: language),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.star_border, size: 13),
                const SizedBox(width: 3),
                Text(_formatCount(stars),
                    style: Theme.of(context).textTheme.bodySmall),
                if (ref != null) ...[
                  const Spacer(),
                  Icon(Icons.link, size: 13, color: cs.primary),
                  const SizedBox(width: 3),
                  Text(
                    '打开详情',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _languageColor(language),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(language, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ── Info icon button ────────────────────────────────────────────────────────

void _showReportInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: '关于每日报告',
      icon: Icons.info_outline_rounded,
      actions: [
        AppDialogAction(
          label: '知道了',
          isPrimary: true,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
      child: const Text(
        '每日报告显示的是前一天的 GitHub Trending 数据。\n\n'
        '当天的报告将在次日生成，因此今天看到的是昨天的报告，这是正常现象。',
        style: TextStyle(height: 1.5),
      ),
    ),
  );
}

class _InfoIconButton extends StatelessWidget {
  const _InfoIconButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CustomPaint(
          size: const Size(18, 18),
          painter: _InfoIconPainter(color: color),
        ),
      ),
    );
  }
}

class _InfoIconPainter extends CustomPainter {
  const _InfoIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 0.8;

    // Circle outline
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..isAntiAlias = true,
    );

    // Exclamation mark — vertical line
    canvas.drawLine(
      Offset(cx, size.height * 0.25),
      Offset(cx, size.height * 0.57),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // Exclamation mark — dot
    canvas.drawCircle(
      Offset(cx, size.height * 0.72),
      1.1,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_InfoIconPainter old) => old.color != color;
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(height: 1.58),
    h1: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.25,
    ),
    h2: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.3,
    ),
    h3: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.35,
      color: cs.primary,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSecondaryContainer,
      fontWeight: FontWeight.w600,
      height: 1.48,
    ),
    blockquoteDecoration: BoxDecoration(
      color: cs.secondaryContainer.withAlpha(100),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.secondary.withAlpha(120)),
    ),
    code: theme.textTheme.bodySmall?.copyWith(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHighest,
    ),
    a: TextStyle(
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
      fontWeight: FontWeight.w600,
    ),
  );
}

Color _languageColor(String language) {
  return Color(int.tryParse(
          Constants.getLanguageColor(language).replaceFirst('#', '0xFF')) ??
      0xFF8b949e);
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatCount(int count) {
  return count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count';
}

bool _isValidRepositoryPart(String value) {
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);
}

String _stripTrailingRepositoryPunctuation(String value) {
  return value.replaceFirst(RegExp(r'[.,，。;；:：!?！？]+$'), '');
}

List<DailyReportRepositoryRef> _uniqueRepositoryNameRefs(
  List<DailyReportRepositoryRef> refs,
) {
  final counts = <String, int>{};
  for (final ref in refs) {
    counts[ref.name] = (counts[ref.name] ?? 0) + 1;
  }
  return refs.where((ref) => counts[ref.name] == 1).toList();
}

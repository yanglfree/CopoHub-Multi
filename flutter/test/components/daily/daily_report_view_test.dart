import 'package:copohub/components/daily/daily_report_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseDailyReportSections extracts title and level 2 sections', () {
    final sections = parseDailyReportSections('''
# Daily Report

Intro paragraph.

## Highlights

First section.

### Detail

Nested detail.

## Insights

Second section.
''');

    expect(sections.title, 'Daily Report');
    expect(sections.introduction.trim(), 'Intro paragraph.');
    expect(sections.sections, hasLength(2));
    expect(sections.sections.first.title, 'Highlights');
    expect(sections.sections.first.markdown, contains('### Detail'));
    expect(sections.sections.last.title, 'Insights');
  });

  test('parseDailyReportSections falls back to article body without headings',
      () {
    final sections = parseDailyReportSections('Only summary text.');

    expect(sections.title, isEmpty);
    expect(sections.introduction, 'Only summary text.');
    expect(sections.sections, isEmpty);
  });

  test('formatDailyReportDateLabel includes date when selected day is today',
      () {
    final label = formatDailyReportDateLabel(
      '2026-05-02',
      now: DateTime(2026, 5, 2, 10),
    );

    expect(label, '今天 (2026-05-02)');
  });

  test('extractDailyReportRepositoryRefs reads full names and heading pairs',
      () {
    final refs = extractDailyReportRepositoryRefs('''
Top project: mattpocock/skills.

### 1. **TradingAgents**（TauricResearch） | ⭐ +2115 | Python
''');

    expect(refs.map((ref) => ref.fullName), [
      'mattpocock/skills',
      'TauricResearch/TradingAgents',
    ]);
  });

  test('linkifyDailyReportRepositories adds application repository links', () {
    final markdown = linkifyDailyReportRepositories(
      'Top project: mattpocock/skills.\n\n'
      '### 1. **TradingAgents**（TauricResearch） | ⭐ +2115 | Python\n\n'
      '- **ruflo（TypeScript）**：enterprise agent platform.\n\n'
      '`TradingAgents` is hot.',
      [
        const DailyReportRepositoryRef(
          owner: 'mattpocock',
          name: 'skills',
        ),
        const DailyReportRepositoryRef(
          owner: 'TauricResearch',
          name: 'TradingAgents',
        ),
        const DailyReportRepositoryRef(
          owner: 'anthropics',
          name: 'ruflo',
        ),
      ],
    );

    expect(
      markdown,
      contains(
        '[mattpocock/skills](copohub://repository/mattpocock/skills)',
      ),
    );
    expect(
      markdown,
      contains(
        '**[TradingAgents](copohub://repository/TauricResearch/TradingAgents)**（TauricResearch）',
      ),
    );
    expect(
      markdown,
      contains(
        '[`TradingAgents`](copohub://repository/TauricResearch/TradingAgents)',
      ),
    );
    expect(
      markdown,
      contains(
        '**[ruflo](copohub://repository/anthropics/ruflo)（TypeScript）**',
      ),
    );
  });

  test('linkifyDailyReportRepositories skips ambiguous short names', () {
    final markdown = linkifyDailyReportRepositories(
      '`skills` appears in two repositories.',
      [
        const DailyReportRepositoryRef(owner: 'mattpocock', name: 'skills'),
        const DailyReportRepositoryRef(owner: 'browserbase', name: 'skills'),
      ],
    );

    expect(markdown, '`skills` appears in two repositories.');
  });

  test('repositoryRouteFromLink maps report links to in-app routes', () {
    expect(
      repositoryRouteFromLink('copohub://repository/mattpocock/skills'),
      '/repository/mattpocock/skills',
    );
    expect(
      repositoryRouteFromLink('https://github.com/warpdotdev/warp'),
      '/repository/warpdotdev/warp',
    );
  });

  test('dailyReportWithRepositoryData fills missing top repositories', () {
    final report = dailyReportWithRepositoryData(
      {'summary': 'Report'},
      [
        {'owner': 'simstudioai', 'name': 'sim'},
      ],
    );

    expect(report['top_repositories'], hasLength(1));
    expect(
      repositoryRefFromData(
        (report['top_repositories'] as List<dynamic>).first
            as Map<String, dynamic>,
      )?.fullName,
      'simstudioai/sim',
    );
  });
}

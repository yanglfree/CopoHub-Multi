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
      '### 1. **TradingAgents**（TauricResearch） | ⭐ +2115 | Python',
      [
        const DailyReportRepositoryRef(
          owner: 'mattpocock',
          name: 'skills',
        ),
        const DailyReportRepositoryRef(
          owner: 'TauricResearch',
          name: 'TradingAgents',
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
}

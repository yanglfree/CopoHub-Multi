import 'package:copohub/pages/repository/readme_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadmeDocumentParser', () {
    test('sanitizes GitHub README HTML and keeps local anchors', () {
      final document = ReadmeDocumentParser.parse('''
<!-- generated -->
<h2 id="install">Install</h2>
<p><strong>Run</strong> <code>flutter test</code></p>

| Name | Value |
| ---- | ----- |
| CopoHub | GitHub client |

## Usage Guide
<img alt="Logo" src="assets/logo.png">
''');

      expect(document.markdown, isNot(contains('<!-- generated -->')));
      expect(document.markdown, contains('**Run**'));
      expect(document.markdown, contains('`flutter test`'));
      expect(document.markdown, contains('![Logo](assets/logo.png)'));

      expect(document.sections, hasLength(3));
      expect(document.sections[0].anchorIds, containsAll(['install']));
      expect(document.sections[1].isTable, isTrue);
      expect(document.sections[2].anchorIds, containsAll(['usage-guide']));
    });
  });

  group('ReadmeLinkResolver', () {
    const context = ReadmeLinkContext(
      owner: 'onevcat',
      repo: 'CopoHub',
      defaultBranch: 'main',
      readmePath: 'docs/README.md',
      downloadUrl:
          'https://raw.githubusercontent.com/onevcat/CopoHub/main/docs/README.md',
      htmlUrl: 'https://github.com/onevcat/CopoHub/blob/main/docs/README.md',
    );

    test('resolves relative README links against the current README path', () {
      const resolver = ReadmeLinkResolver(context);

      expect(
        resolver.resolve('assets/logo.png', forImage: true),
        'https://raw.githubusercontent.com/onevcat/CopoHub/main/docs/assets/logo.png',
      );
      expect(
        resolver.resolve('../LICENSE'),
        'https://github.com/onevcat/CopoHub/blob/main/LICENSE',
      );
    });

    test('recognizes anchors for the current README only', () {
      const resolver = ReadmeLinkResolver(context);

      expect(resolver.currentReadmeAnchor('#install'), 'install');
      expect(resolver.currentReadmeAnchor('README.md#usage'), 'usage');
      expect(resolver.currentReadmeAnchor('../README.md#top'), isNull);
    });

    test('maps repository-level links to detail page tabs', () {
      const resolver = ReadmeLinkResolver(context);

      expect(resolver.currentRepositoryTabIndex('/onevcat/CopoHub/issues'), 2);
      expect(
        resolver.currentRepositoryTabIndex(
          'https://github.com/onevcat/CopoHub/commits/main',
        ),
        3,
      );
      expect(resolver.currentRepositoryTabIndex('releases'), 4);
      expect(resolver.currentRepositoryTabIndex('tree/main/lib'), isNull);
    });
  });
}

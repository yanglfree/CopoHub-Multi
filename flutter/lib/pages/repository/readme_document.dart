import 'dart:convert';

const _readmeAnchorMarker = 'copohub-readme-anchor';

class ReadmeDocument {
  const ReadmeDocument({
    required this.markdown,
    required this.sections,
  });

  final String markdown;
  final List<ReadmeSection> sections;
}

class ReadmeSection {
  const ReadmeSection({
    required this.isTable,
    required this.content,
    this.anchorIds = const [],
  });

  final bool isTable;
  final String content;
  final List<String> anchorIds;
}

class ReadmeDocumentParser {
  const ReadmeDocumentParser._();

  static ReadmeDocument? parseEncodedContent({
    required String content,
    required String encoding,
  }) {
    final decoded = _decodeContent(content, encoding);
    if (decoded == null || decoded.trim().isEmpty) return null;
    return parse(decoded);
  }

  static ReadmeDocument parse(String source) {
    final markdown = _stripHtmlForMarkdown(source);
    return ReadmeDocument(
      markdown: markdown,
      sections: _splitReadmeSections(markdown),
    );
  }

  static String? _decodeContent(String content, String encoding) {
    if (content.isEmpty) return null;
    if (encoding.toLowerCase() != 'base64') return content;
    try {
      return utf8.decode(base64Decode(content.replaceAll('\n', '')));
    } catch (_) {
      return null;
    }
  }

  static String _stripHtmlForMarkdown(String src) {
    var s = src;

    s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '');

    s = s.replaceAllMapped(
      RegExp(
        r'<(script|style|iframe|svg|video|audio|object)\b[^>]*?>[\s\S]*?</\1>',
        caseSensitive: false,
      ),
      (_) => '',
    );

    s = s.replaceAllMapped(
      RegExp(
        r'<pre\b[^>]*?>\s*<code\b[^>]*?>([\s\S]*?)</code>\s*</pre>',
        caseSensitive: false,
      ),
      (m) => '\n```\n${_unescapeHtmlEntities(m.group(1)!)}\n```\n',
    );
    s = s.replaceAllMapped(
      RegExp(r'<pre\b[^>]*?>([\s\S]*?)</pre>', caseSensitive: false),
      (m) => '\n```\n${_unescapeHtmlEntities(m.group(1)!)}\n```\n',
    );

    s = s.replaceAllMapped(
      RegExp(
        r'''<img\b[^>]*?\bsrc\s*=\s*(["'])([^"']*)\1[^>]*?/?>''',
        caseSensitive: false,
      ),
      (m) {
        final src = m.group(2) ?? '';
        final raw = m.group(0)!;
        final altM = RegExp(
          r'''\balt\s*=\s*(["'])([^"']*)\1''',
          caseSensitive: false,
        ).firstMatch(raw);
        return '![${altM?.group(2) ?? ''}]($src)';
      },
    );

    s = s.replaceAllMapped(
      RegExp(
        r'''<a\b[^>]*?\bhref\s*=\s*(["'])([^"']*)\1[^>]*?>([\s\S]*?)</a>''',
        caseSensitive: false,
      ),
      (m) {
        final href = _unescapeHtmlEntities(m.group(2) ?? '');
        final text = _unescapeHtmlEntities(
          (m.group(3) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim(),
        );
        return text.isEmpty ? '' : '[$text]($href)';
      },
    );

    s = s.replaceAllMapped(
      RegExp(
        r'''<h([1-6])\b([^>]*)>([\s\S]*?)</h\1>''',
        caseSensitive: false,
      ),
      (m) {
        final attrs = m.group(2) ?? '';
        final idMatch = RegExp(
          r'''\bid\s*=\s*(["'])([^"']+)\1''',
          caseSensitive: false,
        ).firstMatch(attrs);
        final id = _unescapeHtmlEntities(idMatch?.group(2) ?? '').trim();
        final body = m.group(3) ?? '';
        if (id.isEmpty) return body;
        return '\n<$_readmeAnchorMarker id="$id" />\n$body\n';
      },
    );

    s = s.replaceAllMapped(
      RegExp(r'<(b|strong)\b[^>]*?>([\s\S]*?)</(b|strong)>',
          caseSensitive: false),
      (m) => '**${m.group(2)}**',
    );
    s = s.replaceAllMapped(
      RegExp(r'<(i|em)\b[^>]*?>([\s\S]*?)</(i|em)>', caseSensitive: false),
      (m) => '_${m.group(2)}_',
    );
    s = s.replaceAllMapped(
      RegExp(r'<(del|s|strike)\b[^>]*?>([\s\S]*?)</(del|s|strike)>',
          caseSensitive: false),
      (m) => '~~${m.group(2)}~~',
    );
    s = s.replaceAllMapped(
      RegExp(r'<code\b[^>]*?>([\s\S]*?)</code>', caseSensitive: false),
      (m) => '`${_unescapeHtmlEntities(m.group(1)!)}`',
    );

    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    s = s.replaceAll(
      RegExp(
        r'</?(?:div|span|p|section|article|header|footer|nav|main|aside|center'
        r'|details|summary|table|thead|tbody|tr|td|th|font|small|big|sub|sup'
        r'|kbd|mark|figure|figcaption|picture|source|h[1-6])\b[^>]*?>',
        caseSensitive: false,
      ),
      '',
    );

    s = s.replaceAll(
      RegExp(
        r'<(?:input|meta|link|embed)\b[^>]*?/?>',
        caseSensitive: false,
      ),
      '',
    );

    s = s.replaceAllMapped(
      RegExp(r'^[^\S\n]+(![\[\(])', multiLine: true),
      (m) => m.group(1)!,
    );

    return _unescapeHtmlEntities(s);
  }

  static String _unescapeHtmlEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'&nbsp;?'), '\u00a0');

  static List<ReadmeSection> _splitReadmeSections(String text) {
    final sections = <ReadmeSection>[];
    final buf = StringBuffer();
    bool inTable = false;
    List<String> anchorIds = const [];
    final anchorCounts = <String, int>{};

    void flush() {
      final s = buf.toString();
      if (s.trim().isNotEmpty) {
        sections.add(
          ReadmeSection(
            isTable: inTable,
            content: s,
            anchorIds: anchorIds,
          ),
        );
      }
      buf.clear();
      anchorIds = const [];
    }

    for (final line in text.split('\n')) {
      final explicitAnchor = _htmlAnchorId(line);
      if (explicitAnchor != null) {
        flush();
        inTable = false;
        anchorIds = _explicitAnchorAliases(explicitAnchor);
        continue;
      }

      final headingText = _headingText(line);
      if (headingText != null) {
        flush();
        inTable = false;
        anchorIds = _headingAnchorAliases(headingText, anchorCounts);
        buf.writeln(line);
        continue;
      }

      final tableRow = line.trimLeft().startsWith('|');
      if (tableRow != inTable) {
        flush();
        inTable = tableRow;
      }
      buf.writeln(line);
    }
    flush();
    return sections;
  }

  static String? _htmlAnchorId(String line) {
    final match = RegExp(
      '^<$_readmeAnchorMarker\\s+id="([^"]+)"\\s*/>\$',
    ).firstMatch(line.trim());
    return match?.group(1)?.trim();
  }

  static String? _headingText(String line) {
    final match = RegExp(r'^(#{1,6})[ \t]+(.+?)[ \t#]*$').firstMatch(line);
    if (match == null) return null;
    return match.group(2)?.trim();
  }

  static List<String> _explicitAnchorAliases(String anchor) {
    final normalized = ReadmeAnchors.normalize(anchor);
    return [normalized, 'user-content-$normalized'];
  }

  static List<String> _headingAnchorAliases(
    String heading,
    Map<String, int> anchorCounts,
  ) {
    final aliases = <String>[];
    final base = _githubAnchorSlugBase(heading);
    final count = anchorCounts[base] ?? 0;
    anchorCounts[base] = count + 1;

    final slug = count == 0 ? base : '$base-$count';
    aliases
      ..add(slug)
      ..add('user-content-$slug');

    final plainBase = _plainAnchorSlugBase(heading);
    if (plainBase.isNotEmpty && plainBase != base) {
      final plainSlug = count == 0 ? plainBase : '$plainBase-$count';
      aliases
        ..add(plainSlug)
        ..add('user-content-$plainSlug');
    }

    return aliases;
  }

  static String _githubAnchorSlugBase(String heading) {
    final plain = _plainHeadingText(heading).toLowerCase();
    final buf = StringBuffer();
    var previousWasSpace = false;
    final letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

    for (final rune in plain.runes) {
      final char = String.fromCharCode(rune);
      final isLetterOrNumber = letterOrNumber.hasMatch(char);
      final isWordPunctuation = char == '-' || char == '_';
      final isSpace = char.trim().isEmpty;

      if (isSpace) {
        previousWasSpace = true;
        continue;
      }
      if (isLetterOrNumber || isWordPunctuation) {
        if (previousWasSpace && buf.isNotEmpty) buf.write('-');
        buf.write(char);
        previousWasSpace = false;
      }
    }

    final slug = buf.toString().replaceAll(RegExp(r'-+'), '-');
    return slug.isEmpty ? 'section' : slug;
  }

  static String _plainAnchorSlugBase(String heading) {
    final plain = _plainHeadingText(heading).toLowerCase().trim();
    return plain.replaceAll(RegExp(r'\s+'), '-');
  }

  static String _plainHeadingText(String heading) {
    return _unescapeHtmlEntities(heading)
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[`*_~]'), '')
        .replaceAllMapped(
          RegExp(r'\\([\\`*_{}\[\]()#+\-.!])'),
          (match) => match.group(1) ?? '',
        )
        .trim();
  }
}

class ReadmeLinkContext {
  const ReadmeLinkContext({
    required this.owner,
    required this.repo,
    required this.defaultBranch,
    required this.readmePath,
    required this.downloadUrl,
    required this.htmlUrl,
  });

  final String owner;
  final String repo;
  final String defaultBranch;
  final String readmePath;
  final String downloadUrl;
  final String htmlUrl;
}

class ReadmeLinkResolver {
  const ReadmeLinkResolver(this.context);

  final ReadmeLinkContext context;

  String resolve(String href, {bool forImage = false}) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https' || scheme == 'mailto') {
        return trimmed;
      }
      if (forImage && scheme == 'data') {
        return trimmed;
      }
      return 'about:blank';
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    if (trimmed.startsWith('#')) {
      final base = context.htmlUrl.isNotEmpty
          ? context.htmlUrl
          : 'https://github.com/${context.owner}/${context.repo}';
      return '$base$trimmed';
    }

    if (trimmed.startsWith('/')) {
      final sitePath = trimmed.substring(1);
      if (sitePath.startsWith('${context.owner}/${context.repo}/')) {
        return 'https://github.com$trimmed';
      }
      final path = _normalizeRepoPath(trimmed.substring(1));
      if (forImage) return _rawUrlFor(path);
      return _blobUrlFor(path);
    }

    final baseDir = context.readmePath.contains('/')
        ? context.readmePath.substring(0, context.readmePath.lastIndexOf('/'))
        : '';
    final joined = baseDir.isEmpty ? trimmed : '$baseDir/$trimmed';
    final normalized = _normalizeRepoPath(joined);

    if (forImage) {
      if (context.downloadUrl.isNotEmpty && normalized == context.readmePath) {
        return context.downloadUrl;
      }
      return _rawUrlFor(normalized);
    }

    return _blobUrlFor(normalized);
  }

  String? currentReadmeAnchor(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasFragment || uri.fragment.isEmpty) return null;

    if (trimmed.startsWith('#')) return ReadmeAnchors.normalize(uri.fragment);

    if (uri.hasScheme) {
      return _isCurrentReadmeGitHubUri(uri)
          ? ReadmeAnchors.normalize(uri.fragment)
          : null;
    }

    if (trimmed.startsWith('//')) return null;

    final baseDir = context.readmePath.contains('/')
        ? context.readmePath.substring(0, context.readmePath.lastIndexOf('/'))
        : '';
    final path = uri.path;
    if (path.isEmpty) return ReadmeAnchors.normalize(uri.fragment);

    final joined = path.startsWith('/')
        ? path.substring(1)
        : (baseDir.isEmpty ? path : '$baseDir/$path');
    final normalized = _normalizeRepoPath(joined);
    return normalized == _normalizeRepoPath(context.readmePath)
        ? ReadmeAnchors.normalize(uri.fragment)
        : null;
  }

  int? currentRepositoryTabIndex(String href) {
    final uri = Uri.tryParse(href.trim());
    if (uri == null || uri.hasFragment) return null;

    final pathSegments = _currentRepositoryPathSegments(uri, href);
    if (pathSegments == null) return null;
    if (pathSegments.isEmpty) return 0;

    switch (pathSegments.first) {
      case 'tree':
        return pathSegments.length <= 2 ? 1 : null;
      case 'issues':
        return pathSegments.length == 1 ? 2 : null;
      case 'pulls':
        return pathSegments.length == 1 ? 2 : null;
      case 'commits':
        return pathSegments.length <= 2 ? 3 : null;
      case 'releases':
        return pathSegments.length == 1 ? 4 : null;
      case 'tags':
        return pathSegments.length == 1 ? 4 : null;
      default:
        return null;
    }
  }

  List<String>? _currentRepositoryPathSegments(Uri uri, String href) {
    final trimmed = href.trim();
    if (uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (host != 'github.com' && host != 'www.github.com') return null;

      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length < 2) return null;
      if (segs[0].toLowerCase() != context.owner.toLowerCase() ||
          segs[1].toLowerCase() != context.repo.toLowerCase()) {
        return null;
      }
      return segs.sublist(2);
    }

    if (trimmed.startsWith('//')) return null;

    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (trimmed.startsWith('/')) {
      if (segs.length < 2) return null;
      if (segs[0].toLowerCase() != context.owner.toLowerCase() ||
          segs[1].toLowerCase() != context.repo.toLowerCase()) {
        return null;
      }
      return segs.sublist(2);
    }

    return segs;
  }

  bool _isCurrentReadmeGitHubUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'github.com' && host != 'www.github.com') return false;

    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return false;
    if (segs[0].toLowerCase() != context.owner.toLowerCase() ||
        segs[1].toLowerCase() != context.repo.toLowerCase()) {
      return false;
    }

    if (segs.length == 2) return true;
    if (segs.length >= 5 && segs[2] == 'blob') {
      final path = segs.sublist(4).join('/');
      return _normalizeRepoPath(path) == _normalizeRepoPath(context.readmePath);
    }
    return false;
  }

  String _blobUrlFor(String path) =>
      'https://github.com/${context.owner}/${context.repo}/blob/${context.defaultBranch}/$path';

  String _rawUrlFor(String path) =>
      'https://raw.githubusercontent.com/${context.owner}/${context.repo}/${_encodePath(context.defaultBranch)}/${_encodePath(path)}';

  String _encodePath(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  String _normalizeRepoPath(String path) {
    final output = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (output.isNotEmpty) output.removeLast();
        continue;
      }
      output.add(part);
    }
    return output.join('/');
  }
}

class ReadmeAnchors {
  const ReadmeAnchors._();

  static String normalize(String anchor) {
    final trimmed = anchor.trim().replaceFirst(RegExp(r'^#'), '');
    try {
      return Uri.decodeComponent(trimmed).toLowerCase();
    } catch (_) {
      return trimmed.toLowerCase();
    }
  }
}

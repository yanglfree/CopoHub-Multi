import 'dart:core';

class DailyReportRepositoryRef {
  final String owner;
  final String name;
  const DailyReportRepositoryRef({required this.owner, required this.name});
  String get fullName => owner + '/' + name;
  String get reportLink => 'copohub://repository/' + owner + '/' + name;
}

List<DailyReportRepositoryRef> _uniqueRepositoryNameRefs(
  Iterable<DailyReportRepositoryRef> refs,
) {
  final nameToRefs = <String, List<DailyReportRepositoryRef>>{};
  for (final ref in refs) {
    nameToRefs.putIfAbsent(ref.name, () => []).add(ref);
  }
  return nameToRefs.values
      .where((list) => list.length == 1)
      .map((list) => list.first)
      .toList();
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

    final fullCodeSpanPattern = RegExp('`(' + RegExp.escape(ref.fullName) + ')`');
    linked = linked.replaceAllMapped(fullCodeSpanPattern, (match) {
      final fullName = match.group(1)!;
      return '[`' + fullName + '`](' + ref.reportLink + ')';
    });

    final fullNamePattern = RegExp(
      r'(^|[^`\[\]\w./:-])(' + RegExp.escape(ref.fullName) + r')(?=$|[^\w/:-])',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(fullNamePattern, (match) {
      final prefix = match.group(1)!;
      final fullName = match.group(2)!;
      return prefix + '[' + fullName + '](' + ref.reportLink + ')';
    });
  }

  for (final ref in uniqueNameRefs) {
    final boldNameWithSuffixPattern = RegExp(
      r'\*\*(' + RegExp.escape(ref.name) + r')([（(][^）)\n]+[）)])\*\*',
    );
    linked = linked.replaceAllMapped(boldNameWithSuffixPattern, (match) {
      final name = match.group(1)!;
      final suffix = match.group(2)!;
      return '**[' + name + '](' + ref.reportLink + ')' + suffix + '**';
    });

    final codeSpanPattern = RegExp('`(' + RegExp.escape(ref.name) + ')`');
    linked = linked.replaceAllMapped(codeSpanPattern, (match) {
      final name = match.group(1)!;
      return '[`' + name + '`](' + ref.reportLink + ')';
    });

    final h3NumberedPattern = RegExp(
      r'^(###[ \t]+\d+\.[ \t]+)(' + RegExp.escape(ref.name) + r')(?!\w)',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(h3NumberedPattern, (match) {
      return match.group(1)! + '[' + match.group(2)! + '](' + ref.reportLink + ')';
    });

    final h3PlainPattern = RegExp(
      r'^(###[ \t]+)(' + RegExp.escape(ref.name) + r')(?!\w)',
      multiLine: true,
    );
    linked = linked.replaceAllMapped(h3PlainPattern, (match) {
      return match.group(1)! + '[' + match.group(2)! + '](' + ref.reportLink + ')';
    });
  }

  return linked;
}

void main() {
  var refs = [DailyReportRepositoryRef(owner: 'Hmbown', name: 'DeepSeek-TUI')];
  
  var cases = [
    '### 深度解析 1：[Hmbown/DeepSeek-TUI](https://github.com/Hmbown/DeepSeek-TUI)',
    '### 深度解析 1：Hmbown/DeepSeek-TUI',
    '### 深度解析 1：`Hmbown/DeepSeek-TUI`',
    '### [Hmbown/DeepSeek-TUI](https://github.com/Hmbown/DeepSeek-TUI)：Rust语言的AI代理新范式',
    '### Hmbown/DeepSeek-TUI：Rust语言的AI代理新范式',
    '### `Hmbown/DeepSeek-TUI`：Rust语言的AI代理新范式',
  ];
  
  for (var c in cases) {
    var out = linkifyDailyReportRepositories(c, refs);
    print('IN:  ' + c + '\nOUT: ' + out + '\n');
  }
}

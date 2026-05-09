void main() {
  var text = '### 深度解析 1：[Hmbown/DeepSeek-TUI](https://github.com/Hmbown/DeepSeek-TUI) —— 终端极客的AI编码利器';
  var h3PlainPattern = RegExp(r'^(###[ \t]+)(DeepSeek-TUI)(?!\w)', multiLine: true);
  var linked = text.replaceAllMapped(h3PlainPattern, (match) {
      return '${match.group(1)!}[${match.group(2)!}](copohub://repository/Hmbown/DeepSeek-TUI)';
  });
  print(linked);
}

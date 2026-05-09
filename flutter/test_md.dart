import 'package:markdown/markdown.dart';

void main() {
  var md = '### 深度解析 1：[Hmbown/DeepSeek-TUI](copohub://repository/Hmbown/DeepSeek-TUI) —— 终端极客的AI编码利器';
  var html = markdownToHtml(md);
  print(html);
}

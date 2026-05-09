import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  testWidgets('markdown link test', (WidgetTester tester) async {
    var md = '### 深度解析 1：[`Hmbown/DeepSeek-TUI`](copohub://repository/Hmbown/DeepSeek-TUI) —— 终端极客的AI编码利器';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownBody(
          data: md,
        ),
      ),
    ));
    
    final RichText richText = tester.widget(find.byType(RichText).first);
    print('Output: ' + richText.text.toPlainText());
  });
}

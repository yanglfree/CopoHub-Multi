void main() {
  var fullName = 'Hmbown/DeepSeek-TUI';
  var regex = RegExp(r'(^|[^\[\]\w./:-])(' + RegExp.escape(fullName) + r')(?=$|[^\w/:-])', multiLine: true);
  var text = '### 深度解析 1：[Hmbown/DeepSeek-TUI](https://github.com/Hmbown/DeepSeek-TUI) —— 终端极客的AI编码利器';
  
  var linked = text.replaceAllMapped(regex, (match) {
    return '${match.group(1)}[${match.group(2)}](copohub://repository/${match.group(2)})';
  });
  print(linked);
}

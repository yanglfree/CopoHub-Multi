import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'daily_report_view.dart';

const _kCardWidth = 375.0;
const _kQrUrl = 'https://copohub.com';
const _kSlogan = '每天发现更多精彩仓库，尽在 CopoHub';

// ── Public API ────────────────────────────────────────────────────────────────

Future<void> showDailyReportShareSheet(
  BuildContext context,
  Map<String, dynamic> report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShareSheet(report: report),
  );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.report});
  final Map<String, dynamic> report;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Wait two frames: one for the button rebuild, one for the card paint.
      await Future.delayed(Duration.zero);
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;

      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError('无法获取卡片内容，请稍后重试');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError('图片生成失败，请稍后重试');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final file = await _saveTempPng(bytes);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'GitHub Daily Report',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e, st) {
      debugPrint('DailyReportShare error: $e\n$st');
      _showError('分享失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    // Use rootContext messenger to avoid bottom-sheet context issues.
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<File> _saveTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/daily_report_$ts.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
            child: Row(
              children: [
                const Text(
                  '分享预览',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF24292F),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // ── Scrollable card preview ──────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: DailyReportShareCard(report: widget.report),
                ),
              ),
            ),
          ),
          // ── Share button ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_outlined),
                label: Text(
                  _sharing ? '生成中…' : '分享图片',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share card widget (the actual image content) ──────────────────────────────

class DailyReportShareCard extends StatelessWidget {
  const DailyReportShareCard({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final summary = report['summary'] as String? ?? '';
    final topics = (report['topics'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    final topRepos = (report['top_repositories'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final sections = parseDailyReportSections(summary);
    final title =
        sections.title.isEmpty ? 'GitHub Trending 日报' : sections.title;
    final date = report['date'] as String?;
    final language = report['language'] as String?;

    final introText = _plainText(sections.introduction);
    final truncatedIntro =
        introText.length > 200 ? '${introText.substring(0, 200)}…' : introText;

    return Container(
      width: _kCardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header gradient ─────────────────────────────────────────────
          _CardHeader(title: title, date: date, language: language),
          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (topics.isNotEmpty) ...[
                  _CardTopics(topics: topics.take(6).toList()),
                  const SizedBox(height: 12),
                ],
                if (truncatedIntro.isNotEmpty) ...[
                  Text(
                    truncatedIntro,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF444444),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (topRepos.isNotEmpty) ...[
                  const _CardLabel(text: '精选仓库'),
                  const SizedBox(height: 8),
                  ...topRepos.take(3).map((r) => _CardRepoRow(data: r)),
                  const SizedBox(height: 14),
                ],
                if (sections.sections.length > 1) ...[
                  const _CardLabel(text: '本期亮点'),
                  const SizedBox(height: 8),
                  ...sections.sections.take(4).toList().asMap().entries.map(
                        (e) => _CardSectionRow(
                            index: e.key + 1, title: e.value.title),
                      ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          // ── Footer with QR code ─────────────────────────────────────────
          const _CardFooter(),
        ],
      ),
    );
  }
}

// ── Card sub-widgets ──────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    this.date,
    this.language,
  });

  final String title;
  final String? date;
  final String? language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1117), Color(0xFF1C2A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child:
                    const Icon(Icons.auto_graph, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'GitHub Daily Report',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (language != null && language!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    language!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatShareDate(date!),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatShareDate(String value) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    return '${dt.year}年${dt.month.toString().padLeft(2, '0')}月${dt.day.toString().padLeft(2, '0')}日';
  }
}

class _CardTopics extends StatelessWidget {
  const _CardTopics({required this.topics});

  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: topics
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDDF4FF),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  color: Color(0xFF0969DA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0969DA),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF24292F),
          ),
        ),
      ],
    );
  }
}

class _CardRepoRow extends StatelessWidget {
  const _CardRepoRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ownerValue = data['owner'];
    final owner = ownerValue is Map<String, dynamic>
        ? ownerValue['login'] as String? ?? ''
        : ownerValue as String? ?? '';
    final name = data['name'] as String? ?? data['repo'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final stars = data['stars'] as int? ?? 0;
    final language = data['language'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.code, size: 13, color: Color(0xFF57606A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$owner/$name',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0969DA),
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF57606A)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (language.isNotEmpty) ...[
                Text(
                  language,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF57606A)),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.star_border, size: 12, color: Color(0xFF57606A)),
              const SizedBox(width: 2),
              Text(
                _fmt(stars),
                style: const TextStyle(fontSize: 11, color: Color(0xFF57606A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _CardSectionRow extends StatelessWidget {
  const _CardSectionRow({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0969DA).withOpacity(0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF0969DA),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF24292F),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FA),
        border: Border(
          top: BorderSide(color: Color(0xFFD0D7DE)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          QrImageView(
            data: _kQrUrl,
            version: QrVersions.auto,
            size: 60,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0D1117),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0D1117),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CopoHub',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0D1117),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _kSlogan,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF57606A),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _kQrUrl,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0969DA),
                    fontWeight: FontWeight.w500,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

String _plainText(String markdown) {
  if (markdown.isEmpty) return '';
  var text = markdown;
  // Remove image syntax
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  // Remove links: [text](url) → text
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  // Remove heading markers
  text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  // Remove bold / italic / strikethrough
  text = text.replaceAll(RegExp(r'\*{1,3}|_{1,3}|~~'), '');
  // Remove inline code
  text = text.replaceAll(RegExp(r'`[^`]*`'), '');
  // Remove list markers
  text = text.replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
  // Collapse whitespace
  text = text.replaceAll(RegExp(r'\n+'), ' ');
  text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
  return text.trim();
}

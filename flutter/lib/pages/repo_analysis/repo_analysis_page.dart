import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/daily_api_client.dart';
import '../../components/markdown/markdown_scroll_fix.dart';
import '../../models/repo_analysis.dart';

/// AI repository analysis page.
/// Mirrors HarmonyOS RepoAnalysisPage.
///
/// Receives [owner] and [repo] either as path params or via [extra]:
/// ```dart
/// context.push('/repo-analysis', extra: {'owner': 'torvalds', 'repo': 'linux'});
/// ```
class RepoAnalysisPage extends StatefulWidget {
  const RepoAnalysisPage({
    super.key,
    required this.owner,
    required this.repo,
  });
  final String owner;
  final String repo;

  @override
  State<RepoAnalysisPage> createState() => _RepoAnalysisPageState();
}

enum _LoadState { loading, generating, success, notFound, error }

class _RepoAnalysisPageState extends State<RepoAnalysisPage> {
  final _api = DailyApiClient.instance;

  _LoadState _state = _LoadState.loading;
  RepoAnalysis? _analysis;
  String _error = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _state = _LoadState.loading;
      _error = '';
    });

    final result = await _api.getRepoAnalysis(widget.owner, widget.repo);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final analysis = result.data!;
      setState(() {
        _analysis = analysis;
        _state = analysis.isPublished
            ? _LoadState.success
            : analysis.isFailed
                ? _LoadState.error
                : _LoadState.generating;
      });
      if (analysis.isGenerating) _schedulePoll();
    } else if (result.message?.contains('暂无') == true ||
        result.message?.contains('404') == true) {
      setState(() => _state = _LoadState.notFound);
    } else {
      setState(() {
        _state = _LoadState.error;
        _error = result.message ?? '加载失败';
      });
    }
  }

  Future<void> _triggerGeneration() async {
    setState(() {
      _state = _LoadState.generating;
      _error = '';
    });

    final result = await _api.triggerRepoAnalysis(widget.owner, widget.repo);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final analysis = result.data!;
      setState(() {
        _analysis = analysis;
        _state = analysis.isPublished
            ? _LoadState.success
            : analysis.isFailed
                ? _LoadState.error
                : _LoadState.generating;
      });
      if (analysis.isGenerating) _schedulePoll();
    } else {
      setState(() {
        _state = _LoadState.error;
        _error = result.message ?? '生成失败';
      });
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _loadAnalysis();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.owner}/${widget.repo}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (_state == _LoadState.success)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '在 GitHub 打开',
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/${widget.owner}/${widget.repo}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _LoadState.loading => const Center(child: CircularProgressIndicator()),
      _LoadState.generating => _GeneratingView(
          owner: widget.owner,
          repo: widget.repo,
        ),
      _LoadState.notFound => _NotFoundView(
          owner: widget.owner,
          repo: widget.repo,
          onGenerate: _triggerGeneration,
        ),
      _LoadState.error => _ErrorView(
          message: _error,
          onRetry: _loadAnalysis,
        ),
      _LoadState.success => _AnalysisContent(analysis: _analysis!),
    };
  }
}

// ── Generating view ───────────────────────────────────────────────────────────

class _GeneratingView extends StatefulWidget {
  const _GeneratingView({required this.owner, required this.repo});
  final String owner;
  final String repo;

  @override
  State<_GeneratingView> createState() => _GeneratingViewState();
}

class _GeneratingViewState extends State<_GeneratingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _anim,
              child: Icon(Icons.auto_awesome, size: 56, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'AI 正在分析',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.owner}/${widget.repo}',
              style: TextStyle(color: cs.primary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '正在生成 AI 分析报告，通常需要 30-60 秒\n报告生成后将自动显示',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Not found view ────────────────────────────────────────────────────────────

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({
    required this.owner,
    required this.repo,
    required this.onGenerate,
  });
  final String owner;
  final String repo;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 56, color: cs.outline),
            const SizedBox(height: 24),
            Text(
              '暂无分析报告',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '$owner/$repo 尚未生成 AI 分析报告',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.play_arrow),
              label: const Text('生成分析报告'),
            ),
            const SizedBox(height: 8),
            Text(
              '报告将由 AI 自动生成，通常需要 30-60 秒',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message.isNotEmpty ? message : '加载失败',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

// ── Analysis content ──────────────────────────────────────────────────────────

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.analysis});
  final RepoAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repo header card
          _RepoHeaderCard(analysis: analysis),
          const SizedBox(height: 16),

          // AI title
          if (analysis.analysisTitle.isNotEmpty) ...[
            Text(
              analysis.analysisTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],

          // Summary chip
          if (analysis.analysisSummary.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                analysis.analysisSummary,
                style: TextStyle(
                    fontSize: 13, color: cs.onPrimaryContainer, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main markdown content
          if (analysis.analysisContent.isNotEmpty) ...[
            MarkdownScrollFix(
              child: MarkdownBody(
                data: analysis.analysisContent,
                selectable: true,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href),
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tech stack chips
          if (analysis.techStack.isNotEmpty) ...[
            const _SectionHeader(title: '技术栈'),
            const SizedBox(height: 8),
            _ChipSection(data: analysis.techStack),
            const SizedBox(height: 16),
          ],

          // Key features
          if (analysis.keyFeatures.isNotEmpty) ...[
            const _SectionHeader(title: '核心功能'),
            const SizedBox(height: 8),
            _ChipSection(data: analysis.keyFeatures),
            const SizedBox(height: 16),
          ],

          // Use cases
          if (analysis.useCases.isNotEmpty) ...[
            const _SectionHeader(title: '使用场景'),
            const SizedBox(height: 8),
            _ChipSection(data: analysis.useCases),
            const SizedBox(height: 16),
          ],

          // Footer metadata
          if (analysis.aiModel.isNotEmpty || analysis.updatedAt.isNotEmpty)
            _MetaFooter(analysis: analysis),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RepoHeaderCard extends StatelessWidget {
  const _RepoHeaderCard({required this.analysis});
  final RepoAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.source, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${analysis.owner}/${analysis.name}',
                    style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
            if (analysis.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(analysis.description,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (analysis.language.isNotEmpty) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(analysis.language, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.star_border, size: 13),
                const SizedBox(width: 2),
                Text(_fmt(analysis.stars),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final label = e.value is String ? e.value as String : e.key;
        return Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _MetaFooter extends StatelessWidget {
  const _MetaFooter({required this.analysis});
  final RepoAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                if (analysis.aiModel.isNotEmpty) '模型: ${analysis.aiModel}',
                if (analysis.tokensUsed > 0) 'Tokens: ${analysis.tokensUsed}',
                if (analysis.updatedAt.isNotEmpty)
                  '更新: ${_fmtDate(analysis.updatedAt)}',
              ].join('  ·  '),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/markdown/markdown_scroll_fix.dart';
import '../../models/copohub_curated_item.dart';
import '../../utils/repo_metadata_style.dart';

/// Detail page for a CopoHub curated/featured repository.
/// Receives a [CopoHubCuratedItem] via GoRouter [extra].
class CuratedDetailPage extends StatelessWidget {
  const CuratedDetailPage({super.key, required this.item});
  final CopoHubCuratedItem item;

  static String _fmtStars(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  static String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final metadataColor = repoMetadataColor(cs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('精选仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: '在 GitHub 打开',
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/${item.owner}/${item.repo}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ──────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                              'https://avatars.githubusercontent.com/${item.owner}'),
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => context.push(
                                    '/repository/${item.owner}/${item.repo}'),
                                child: Text(
                                  item.fullName,
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (item.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    item.description,
                                    style: tt.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stats row
                    Row(
                      children: [
                        if (item.language.isNotEmpty) ...[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(item.language,
                              style: TextStyle(
                                  fontSize: 12, color: metadataColor)),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.star_border, size: 14, color: metadataColor),
                        const SizedBox(width: 2),
                        Text(_fmtStars(item.stars),
                            style:
                                TextStyle(fontSize: 12, color: metadataColor)),
                        const SizedBox(width: 16),
                        Icon(Icons.call_split, size: 14, color: metadataColor),
                        const SizedBox(width: 2),
                        Text(_fmtStars(item.forks),
                            style:
                                TextStyle(fontSize: 12, color: metadataColor)),
                        const Spacer(),
                        if (item.isPromoted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7C948),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Promoted',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    if (item.curatedAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '收录于 ${_fmtDate(item.curatedAt)}',
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Curator note ──────────────────────────────────────────────────
            if (item.curatorNote.isNotEmpty) ...[
              _Section(
                icon: Icons.person_outline,
                title: '编辑推荐',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.curatorNote,
                    style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontSize: 14,
                        height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── AI summary ────────────────────────────────────────────────────
            if (item.aiSummary.isNotEmpty) ...[
              _Section(
                icon: Icons.auto_awesome_outlined,
                title: 'AI 摘要',
                child: MarkdownScrollFix(
                  child: MarkdownBody(
                    data: item.aiSummary,
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── View repo button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/repository/${item.owner}/${item.repo}'),
                icon: const Icon(Icons.source),
                label: const Text('查看仓库详情'),
              ),
            ),

            // ── AI analysis button ────────────────────────────────────────────
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/repo-analysis',
                  extra: {
                    'owner': item.owner,
                    'repo': item.repo,
                  },
                ),
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('查看分析报告'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

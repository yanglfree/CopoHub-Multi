import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';

/// 新建仓库页面 — matches the design from the app screenshots.
class CreateRepoPage extends StatefulWidget {
  const CreateRepoPage({super.key});

  @override
  State<CreateRepoPage> createState() => _CreateRepoPageState();
}

class _CreateRepoPageState extends State<CreateRepoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isPrivate = false;
  bool _hasIssues = true;
  bool _hasProjects = true;
  bool _hasWiki = true;
  bool _autoInit = true;

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final result = await GitHubApiClient.instance.createRepository({
      'name': _nameCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      'private': _isPrivate,
      'has_issues': _hasIssues,
      'has_projects': _hasProjects,
      'has_wiki': _hasWiki,
      'auto_init': _autoInit,
    });

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess && result.data != null) {
      final repo = result.data!;
      context.pop();
      context.push('/repository/${repo.owner?.login}/${repo.name}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '创建失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canCreate = _nameCtrl.text.trim().isNotEmpty && !_loading;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text('取消', style: TextStyle(color: cs.primary, fontSize: 16)),
        ),
        leadingWidth: 60,
        title: const Text('新建仓库',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: canCreate ? _create : null,
            child: Text(
              '创建',
              style: TextStyle(
                color: canCreate ? cs.primary : cs.onSurfaceVariant,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // ── 仓库详情 ───────────────────────────────────────────────────
            const _SectionLabel(label: '仓库详情'),
            _InputCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDeco('仓库名称', cs),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '请输入仓库名称';
                      final valid = RegExp(r'^[a-zA-Z0-9._-]+$');
                      if (!valid.hasMatch(v.trim())) {
                        return '只能包含字母、数字、连字符、下划线和点';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const Divider(height: 1),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: _inputDeco('仓库描述 (可选)', cs),
                    maxLines: 3,
                    minLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 可见性 ─────────────────────────────────────────────────────
            const _SectionLabel(label: '可见性'),
            _InputCard(
              child: _ToggleRow(
                title: '私有仓库',
                subtitle: _isPrivate ? '只有你和你添加的协作者可见' : '任何人都可以看到这个仓库',
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ),
            const SizedBox(height: 20),

            // ── 功能 ───────────────────────────────────────────────────────
            const _SectionLabel(label: '功能'),
            _InputCard(
              child: Column(
                children: [
                  _CheckRow(
                    title: '问题',
                    subtitle: '用于追踪任务和 Bug',
                    value: _hasIssues,
                    onChanged: (v) => setState(() => _hasIssues = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  _CheckRow(
                    title: '项目',
                    subtitle: '使用项目视图管理工作流',
                    value: _hasProjects,
                    onChanged: (v) => setState(() => _hasProjects = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  _CheckRow(
                    title: 'Wiki',
                    subtitle: '为仓库编写文档',
                    value: _hasWiki,
                    onChanged: (v) => setState(() => _hasWiki = v),
                  ),
                  const Divider(height: 1, indent: 16),
                  _CheckRow(
                    title: '添加 README 文件',
                    subtitle: '自动生成 README.md 初始化仓库',
                    value: _autoInit,
                    onChanged: (v) => setState(() => _autoInit = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 初始化仓库 ─────────────────────────────────────────────────
            const _SectionLabel(label: '初始化仓库'),
            _InputCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  '创建后可以添加 .gitignore 模板和开源协议',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Create button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: canCreate ? _create : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('创建仓库',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, ColorScheme cs) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value ? cs.primary : cs.outline,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: Colors.white, size: 15)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

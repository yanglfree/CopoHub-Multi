import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../models/repository.dart';

/// Page for creating a new Pull Request in a repository.
class CreatePrPage extends StatefulWidget {
  const CreatePrPage({
    super.key,
    required this.owner,
    required this.repo,
  });
  final String owner;
  final String repo;

  @override
  State<CreatePrPage> createState() => _CreatePrPageState();
}

class _CreatePrPageState extends State<CreatePrPage> {
  final _api = GitHubApiClient.instance;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  List<String> _branches = [];
  bool _branchesLoading = true;
  String _head = '';
  String _base = '';
  bool _draft = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() => _branchesLoading = true);
    // Fetch repo info (for default branch) and branches in parallel
    final results = await Future.wait([
      _api.getRepository(widget.owner, widget.repo),
      _api.getRepositoryBranches(widget.owner, widget.repo),
    ]);
    if (!mounted) return;

    final repoResult = results[0];
    final branchResult = results[1];

    if (!branchResult.isSuccess) {
      setState(() => _branchesLoading = false);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('加载分支失败: ${branchResult.message ?? ''}')),
        );
      }
      return;
    }

    final branches = (branchResult.data as List<dynamic>?)
            ?.map((b) => b['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    // Determine default branch: prefer repo metadata, fall back to 'main'/'master'
    String defaultBranch = 'main';
    if (repoResult.isSuccess && repoResult.data != null) {
      defaultBranch = (repoResult.data as Repository).defaultBranch;
    }
    // Ensure defaultBranch is actually in the list
    if (!branches.contains(defaultBranch)) {
      defaultBranch = branches.firstWhere(
        (b) => b == 'main' || b == 'master',
        orElse: () => branches.isNotEmpty ? branches.first : '',
      );
    }

    // head: first branch that is NOT the default branch
    final nonDefault = branches.where((b) => b != defaultBranch).toList();
    final headDefault =
        nonDefault.isNotEmpty ? nonDefault.first : defaultBranch;

    setState(() {
      _branches = branches;
      _branchesLoading = false;
      _base = defaultBranch;
      _head = headDefault;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_head.isEmpty || _base.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('请选择 head 和 base 分支')),
      );
      return;
    }
    if (_head == _base) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('head 分支和 base 分支不能相同')),
      );
      return;
    }
    setState(() => _submitting = true);
    final r = await _api.createPullRequest(
      widget.owner,
      widget.repo,
      title: _titleCtrl.text.trim(),
      head: _head,
      base: _base,
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      draft: _draft,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.isSuccess) {
      final number = r.data?['number'] as int?;
      if (number != null) {
        context.pushReplacement(
            '/pr/${widget.owner}/${widget.repo}/$number');
      } else {
        context.pop();
      }
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('创建 PR 失败: ${r.message ?? ''}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建 Pull Request'),
        actions: [
          _submitting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
                  onPressed: _submit,
                  child: const Text('提交'),
                ),
        ],
      ),
      body: _branchesLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Branch selectors ─────────────────────────────────────
                  Text('Base 分支（合并目标）',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _base.isNotEmpty ? _base : null,
                    items: _branches
                        .map((b) =>
                            DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _base = v);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Compare 分支（要合并的源分支）',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _head.isNotEmpty ? _head : null,
                    items: _branches
                        .map((b) =>
                            DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _head = v);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Title ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: '标题 *',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '标题不能为空';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // ── Body ──────────────────────────────────────────────────
                  TextFormField(
                    controller: _bodyCtrl,
                    minLines: 4,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: '描述（可选）',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Draft toggle ──────────────────────────────────────────
                  SwitchListTile(
                    value: _draft,
                    onChanged: (v) => setState(() => _draft = v),
                    title: const Text('草稿 PR'),
                    subtitle:
                        const Text('草稿 PR 不能被合并，适合未完成的工作'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('创建 Pull Request'),
                  ),
                ],
              ),
            ),
    );
  }
}

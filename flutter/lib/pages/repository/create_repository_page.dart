import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';

/// Create repository page — mirrors HarmonyOS CreateRepositoryView.
class CreateRepositoryPage extends StatefulWidget {
  const CreateRepositoryPage({super.key});

  @override
  State<CreateRepositoryPage> createState() => _CreateRepositoryPageState();
}

class _CreateRepositoryPageState extends State<CreateRepositoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isPrivate = false;
  bool _addReadme = true;
  bool _enableIssues = true;
  bool _enableWiki = false;
  String _selectedGitignore = '无';
  String _selectedLicense = '';
  bool _creating = false;

  final _gitignoreOptions = const [
    '无',
    'Node',
    'Python',
    'Java',
    'Go',
    'Rust',
    'Swift',
    'Dart'
  ];
  final _licenseOptions = const [
    _License('无', ''),
    _License('MIT License', 'mit'),
    _License('Apache License 2.0', 'apache-2.0'),
    _License('GPL v3', 'gpl-3.0'),
    _License('BSD 3-Clause', 'bsd-3-clause'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _creating = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'private': _isPrivate,
      'auto_init': _addReadme,
      'has_issues': _enableIssues,
      'has_wiki': _enableWiki,
    };
    if (_selectedGitignore != '无') {
      data['gitignore_template'] = _selectedGitignore;
    }
    if (_selectedLicense.isNotEmpty) {
      data['license_template'] = _selectedLicense;
    }

    final result = await GitHubApiClient.instance.createRepository(data);
    if (!mounted) return;
    setState(() => _creating = false);

    if (result.isSuccess && result.data != null) {
      final repo = result.data!;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('仓库创建成功！')));
      // Navigate to the new repo detail page
      context.pushReplacement('/repository/${repo.fullName}');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message ?? '创建失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('新建仓库', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          _creating
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
                  onPressed: _create,
                  child: const Text('创建',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Repo name
            _SectionLabel('仓库名称 *'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'my-awesome-project',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '仓库名称不能为空';
                if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(v.trim())) {
                  return '仅允许字母、数字、短横线、下划线和点';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Description
            _SectionLabel('描述（可选）'),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: '仓库简介...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Visibility
            _SectionLabel('可见性'),
            _VisibilitySelector(
              isPrivate: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
            ),
            const SizedBox(height: 16),

            // Init options
            _SectionLabel('初始化选项'),
            _SwitchTile(
              title: '添加 README 文件',
              subtitle: '建议添加，方便描述项目',
              value: _addReadme,
              onChanged: (v) => setState(() => _addReadme = v),
            ),
            _SwitchTile(
              title: '启用 Issues',
              value: _enableIssues,
              onChanged: (v) => setState(() => _enableIssues = v),
            ),
            _SwitchTile(
              title: '启用 Wiki',
              value: _enableWiki,
              onChanged: (v) => setState(() => _enableWiki = v),
            ),
            const SizedBox(height: 16),

            // .gitignore template
            _SectionLabel('.gitignore 模板'),
            _DropdownTile<String>(
              label: '.gitignore',
              value: _selectedGitignore,
              options: _gitignoreOptions,
              labelFor: (v) => v,
              onChanged: (v) => setState(() => _selectedGitignore = v),
            ),
            const SizedBox(height: 16),

            // License
            _SectionLabel('开源协议'),
            _DropdownTile<_License>(
              label: '协议',
              value: _licenseOptions.firstWhere(
                  (l) => l.value == _selectedLicense,
                  orElse: () => _licenseOptions.first),
              options: _licenseOptions,
              labelFor: (l) => l.label,
              onChanged: (l) => setState(() => _selectedLicense = l.value),
            ),
            const SizedBox(height: 32),

            // Create button (bottom)
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('创建仓库'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({required this.isPrivate, required this.onChanged});
  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VisCard(
            icon: Icons.public,
            label: '公开',
            subtitle: '所有人可见',
            selected: !isPrivate,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VisCard(
            icon: Icons.lock_outline,
            label: '私有',
            subtitle: '仅自己可见',
            selected: isPrivate,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _VisCard extends StatelessWidget {
  const _VisCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(10),
          color: selected ? cs.primaryContainer : cs.surfaceContainerLowest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.primary : null)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile(
      {required this.title,
      this.subtitle,
      required this.value,
      required this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      );
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // h-flutter 3.22 does not support initialValue.
      // ignore: deprecated_member_use
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((o) => DropdownMenuItem(
                value: o,
                child: Text(labelFor(o)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _License {
  const _License(this.label, this.value);
  final String label;
  final String value;
}

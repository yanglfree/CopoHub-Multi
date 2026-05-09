import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/github_api_client.dart';
import '../../l10n/app_localizations.dart';

/// Page for creating a new Issue in a repository.
class CreateIssuePage extends StatefulWidget {
  const CreateIssuePage({
    super.key,
    required this.owner,
    required this.repo,
  });
  final String owner;
  final String repo;

  @override
  State<CreateIssuePage> createState() => _CreateIssuePageState();
}

class _CreateIssuePageState extends State<CreateIssuePage> {
  final _api = GitHubApiClient.instance;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _submitting = true);

    final r = await _api.createIssue(
      widget.owner,
      widget.repo,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (r.isSuccess) {
      final number = r.data?['number'] as int?;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.createIssueSuccess)),
      );
      if (number != null) {
        context
            .pushReplacement('/issue/${widget.owner}/${widget.repo}/$number');
      } else {
        context.pop();
      }
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
            content: Text('${l10n.createIssueFailed}: ${r.message ?? ''}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createIssue),
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
                  child: Text(l10n.submit),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Title ─────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.issueTitle,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.titleCannotBeEmpty;
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
                labelText: l10n.issueBody,
                alignLabelWithHint: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(l10n.createIssue),
            ),
          ],
        ),
      ),
    );
  }
}

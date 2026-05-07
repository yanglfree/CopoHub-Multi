import 'package:flutter/material.dart';
import '../dialogs/app_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Privacy policy + service terms dialog — mirrors HarmonyOS PolicyDialog.
enum PolicyTab { privacy, terms }

class PolicyDialog extends StatefulWidget {
  const PolicyDialog({
    super.key,
    this.initialTab = PolicyTab.privacy,
    this.onAccept,
    this.onDecline,
    this.showActions = false,
  });

  final PolicyTab initialTab;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// When [showActions] is true, shows Accept / Decline buttons (used in
  /// first-launch flow). Otherwise shows only a "Close" button.
  final bool showActions;

  @override
  State<PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<PolicyDialog> {
  late PolicyTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AppDialog(
      title: l10n.privacyPolicyTitle,
      icon: Icons.privacy_tip_outlined,
      maxWidth: 520,
      actions: widget.showActions
          ? [
              AppDialogAction(
                label: l10n.decline,
                onPressed: () {
                  widget.onDecline?.call();
                  Navigator.of(context).pop();
                },
              ),
              AppDialogAction(
                label: l10n.accept,
                isPrimary: true,
                onPressed: () {
                  widget.onAccept?.call();
                  Navigator.of(context).pop();
                },
              ),
            ]
          : [
              AppDialogAction(
                label: l10n.close,
                isPrimary: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/icon.png',
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hub, color: cs.primary, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tab selector
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TabButton(
                label: l10n.privacyPolicy,
                selected: _activeTab == PolicyTab.privacy,
                onTap: () => setState(() => _activeTab = PolicyTab.privacy),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: l10n.termsOfService,
                selected: _activeTab == PolicyTab.terms,
                onTap: () => setState(() => _activeTab = PolicyTab.terms),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Flexible(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _activeTab == PolicyTab.privacy
                      ? l10n.privacyContent
                      : l10n.termsContent,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.primary,
          ),
        ),
      ),
    );
  }
}

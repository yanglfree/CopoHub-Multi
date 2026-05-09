import 'package:flutter/material.dart';
import 'app_dialog.dart';
import '../../l10n/app_localizations.dart';

class PATHelpDialog extends StatelessWidget {
  const PATHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final steps = [
      l10n.patStep1,
      l10n.patStep2,
      l10n.patStep3,
      l10n.patStep4,
      l10n.patStep5,
      l10n.patStep6,
    ];

    return AppDialog(
      title: l10n.patHelpDialogTitle,
      icon: Icons.key_outlined,
      actions: [
        AppDialogAction(
          label: l10n.close,
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _StepRow(index: i + 1, text: steps[i]),
              if (i < steps.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: textTheme.labelMedium?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  final bool isLoading;
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
    this.maxWidth = 420,
    this.maxHeightFactor = 0.86,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 8),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final List<AppDialogAction> actions;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * maxHeightFactor;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Material(
          color: cs.surface,
          elevation: 16,
          shadowColor: Colors.black.withAlpha(46),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: cs.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: contentPadding,
                  child: child,
                ),
              ),
              if (actions.isNotEmpty) _AppDialogActions(actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDialogActions extends StatelessWidget {
  const _AppDialogActions({required this.actions});

  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Wrap(
        alignment: WrapAlignment.end,
        runSpacing: 8,
        spacing: 10,
        children: [
          for (final action in actions) _AppDialogButton(action: action),
        ],
      ),
    );
  }
}

class _AppDialogButton extends StatelessWidget {
  const _AppDialogButton({required this.action});

  final AppDialogAction action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final foregroundColor = action.isDestructive ? cs.error : null;
    final child = action.isLoading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(action.label);

    if (action.isPrimary || action.isDestructive) {
      return FilledButton(
        style: action.isDestructive
            ? FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              )
            : null,
        onPressed: action.isLoading ? null : action.onPressed,
        child: child,
      );
    }

    return TextButton(
      style: foregroundColor == null
          ? null
          : TextButton.styleFrom(foregroundColor: foregroundColor),
      onPressed: action.isLoading ? null : action.onPressed,
      child: child,
    );
  }
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
  IconData? icon,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      icon: icon,
      actions: [
        AppDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppDialogAction(
          label: confirmLabel,
          isPrimary: true,
          isDestructive: isDestructive,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
      child: Text(
        message,
        style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
      ),
    ),
  );
  return confirmed == true;
}

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 6),
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
    final tt = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * maxHeightFactor;
    final surfaceColor = cs.brightness == Brightness.dark
        ? cs.surfaceContainerHigh
        : cs.surfaceContainerLowest;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Material(
          color: surfaceColor,
          elevation: 18,
          shadowColor: Colors.black.withAlpha(38),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withAlpha(
                            cs.brightness == Brightness.dark ? 128 : 166,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: cs.primary, size: 19),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 86, minHeight: 42),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: action.isDestructive ? cs.error : cs.primary,
            foregroundColor: action.isDestructive ? cs.onError : cs.onPrimary,
            disabledBackgroundColor: cs.onSurface.withAlpha(31),
            disabledForegroundColor: cs.onSurface.withAlpha(97),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          onPressed: action.isLoading ? null : action.onPressed,
          child: child,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72, minHeight: 42),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor ?? cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        onPressed: action.isLoading ? null : action.onPressed,
        child: child,
      ),
    );
  }
}

class AppDialogTextField extends StatelessWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.autofocus = false,
    this.enabled,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final bool autofocus;
  final bool? enabled;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            autofocus: autofocus,
            enabled: enabled,
            keyboardType: keyboardType,
            onSubmitted: onSubmitted,
            decoration: appDialogInputDecoration(
              context,
              hint: hint,
              errorText: errorText,
            ),
          ),
        ],
      ),
    );
  }
}

class AppDialogDropdownField<T> extends StatelessWidget {
  const AppDialogDropdownField({
    super.key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
            ),
          ),
          DropdownButtonFormField<T>(
            value: value,
            decoration: appDialogInputDecoration(context),
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class AppDialogCheckboxTile extends StatelessWidget {
  const AppDialogCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onChanged == null
                            ? cs.onSurface.withAlpha(97)
                            : cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration appDialogInputDecoration(
  BuildContext context, {
  String? hint,
  String? errorText,
}) {
  final cs = Theme.of(context).colorScheme;
  final borderRadius = BorderRadius.circular(12);

  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    isDense: true,
    filled: true,
    fillColor: cs.brightness == Brightness.dark
        ? cs.surfaceContainer
        : cs.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: border(cs.outlineVariant),
    enabledBorder: border(cs.outlineVariant),
    disabledBorder: border(cs.outlineVariant.withAlpha(128)),
    focusedBorder: border(cs.primary, width: 1.4),
    errorBorder: border(cs.error),
    focusedErrorBorder: border(cs.error, width: 1.4),
    hintStyle: TextStyle(
      color: cs.onSurfaceVariant.withAlpha(116),
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    labelStyle: TextStyle(
      color: cs.onSurfaceVariant.withAlpha(190),
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    floatingLabelStyle: TextStyle(
      color: cs.primary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelLabel,
  String? confirmLabel,
  IconData? icon,
  bool isDestructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      icon: icon,
      actions: [
        AppDialogAction(
          label: cancelLabel ?? l10n.cancel,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppDialogAction(
          label: confirmLabel ?? l10n.confirm,
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

import 'package:flutter/material.dart';
import '../../utils/api_error_message.dart';
import '../../l10n/app_localizations.dart';

class ApiErrorView extends StatelessWidget {
  const ApiErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final friendlyMessage = friendlyApiErrorMessage(message);
    final displayTitle = title ?? l10n.loadFailed;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 36 : 52,
              height: compact ? 36 : 52,
              decoration: BoxDecoration(
                color: cs.errorContainer.withAlpha(112),
                borderRadius: BorderRadius.circular(compact ? 14 : 18),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: compact ? 20 : 28,
                color: cs.error,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
            Text(
              displayTitle,
              style: (compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                friendlyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            OutlinedButton.icon(
              style: compact
                  ? OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

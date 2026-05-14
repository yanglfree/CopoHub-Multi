import 'package:flutter/material.dart';

Color repoMetadataColor(ColorScheme colorScheme) =>
    colorScheme.onSurfaceVariant.withAlpha(166);

TextStyle repoMetadataTextStyle(
  BuildContext context, {
  double? fontSize,
  double? height,
  FontWeight? fontWeight,
}) {
  final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
  return base.copyWith(
    color: repoMetadataColor(Theme.of(context).colorScheme),
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
  );
}

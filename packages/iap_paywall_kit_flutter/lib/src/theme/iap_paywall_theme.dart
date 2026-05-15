import 'package:flutter/material.dart';

class IapPaywallTheme {
  const IapPaywallTheme({
    this.bodyBackground = const Color(0xFF111318),
    this.bodyBorder = const Color(0x24FFFFFF),
    this.panelBackground = const Color(0xFF1E2026),
    this.buttonNormal = const Color(0xFF2A2D35),
    this.buttonText = const Color(0xA3FFFFFF),
    this.buttonTextActive = Colors.white,
    this.accentColor = const Color(0xFFFF9A4E),
    this.titleText = const Color(0xFFF8F4EF),
    this.dangerColor = const Color(0xFFFF3B30),
    this.warningColor = const Color(0xFFE69A00),
  });

  final Color bodyBackground;
  final Color bodyBorder;
  final Color panelBackground;
  final Color buttonNormal;
  final Color buttonText;
  final Color buttonTextActive;
  final Color accentColor;
  final Color titleText;
  final Color dangerColor;
  final Color warningColor;
}

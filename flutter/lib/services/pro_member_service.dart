import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

enum ProPlanType { none, monthly, yearly, lifetime }

class ProMemberService extends ChangeNotifier {
  static final ProMemberService _instance = ProMemberService._();
  ProMemberService._();
  static ProMemberService get instance => _instance;

  bool _isPro = false;
  ProPlanType _planType = ProPlanType.none;
  int _expiryTimestamp = 0;

  bool get isPro => _isPro;
  ProPlanType get planType => _planType;
  int get expiryTimestamp => _expiryTimestamp;

  /// Human-readable expiry label, e.g. "2026-04-28 到期" or "永久有效".
  String get expiryLabel {
    if (!_isPro) return '';
    if (_planType == ProPlanType.lifetime || _expiryTimestamp == 0) {
      return '永久有效';
    }
    final dt =
        DateTime.fromMillisecondsSinceEpoch(_expiryTimestamp).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 到期';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool('${Constants.storageAccessToken}_is_pro') ?? false;
    final planStr =
        prefs.getString('${Constants.storageAccessToken}_plan') ?? '';
    _planType = _planFromString(planStr);
    _expiryTimestamp =
        prefs.getInt('${Constants.storageAccessToken}_expiry') ?? 0;
    _validateExpiry();
  }

  Future<void> setPro({
    required bool isPro,
    ProPlanType planType = ProPlanType.none,
    int expiryTimestamp = 0,
  }) async {
    _isPro = isPro;
    _planType = planType;
    _expiryTimestamp = expiryTimestamp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${Constants.storageAccessToken}_is_pro', isPro);
    await prefs.setString(
        '${Constants.storageAccessToken}_plan', planType.name);
    await prefs.setInt(
        '${Constants.storageAccessToken}_expiry', expiryTimestamp);
    notifyListeners();
  }

  Future<void> clear() async {
    await setPro(isPro: false);
  }

  void _validateExpiry() {
    if (_isPro &&
        _expiryTimestamp > 0 &&
        DateTime.now().millisecondsSinceEpoch > _expiryTimestamp) {
      _isPro = false;
      _planType = ProPlanType.none;
    }
  }

  ProPlanType _planFromString(String s) {
    return ProPlanType.values.firstWhere((e) => e.name == s,
        orElse: () => ProPlanType.none);
  }
}

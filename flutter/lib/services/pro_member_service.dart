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
  String _accountKey = '';
  SharedPreferences? _prefs;

  bool get isPro => _isPro;
  ProPlanType get planType => _planType;
  int get expiryTimestamp => _expiryTimestamp;

  /// Human-readable expiry label, e.g. "2026-04-28 到期" or "永久有效".
  String get expiryLabel {
    if (!_isPro) return '';
    if (_planType == ProPlanType.lifetime || _expiryTimestamp == 0) {
      return '永久有效';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(_expiryTimestamp).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 到期';
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _resetInMemory();
  }

  Future<void> useAccount(String? login) async {
    _prefs ??= await SharedPreferences.getInstance();
    final nextAccountKey = _normalizeAccountKey(login);
    if (_accountKey == nextAccountKey && nextAccountKey.isNotEmpty) return;

    _accountKey = nextAccountKey;
    if (_accountKey.isEmpty) {
      _resetInMemory();
      notifyListeners();
      return;
    }

    _isPro = _prefs?.getBool(_key('is_pro')) ?? false;
    _planType = _planFromString(_prefs?.getString(_key('plan')) ?? '');
    _expiryTimestamp = _prefs?.getInt(_key('expiry')) ?? 0;
    await _validateExpiry();
    notifyListeners();
  }

  Future<void> setPro({
    required bool isPro,
    ProPlanType planType = ProPlanType.none,
    int expiryTimestamp = 0,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    _isPro = isPro;
    _planType = planType;
    _expiryTimestamp = expiryTimestamp;
    if (_accountKey.isNotEmpty) {
      await _prefs?.setBool(_key('is_pro'), isPro);
      await _prefs?.setString(_key('plan'), planType.name);
      await _prefs?.setInt(_key('expiry'), expiryTimestamp);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    await setPro(isPro: false);
  }

  Future<void> _validateExpiry() async {
    if (_isPro &&
        _expiryTimestamp > 0 &&
        DateTime.now().millisecondsSinceEpoch > _expiryTimestamp) {
      _isPro = false;
      _planType = ProPlanType.none;
      _expiryTimestamp = 0;
      if (_accountKey.isNotEmpty) {
        await _prefs?.setBool(_key('is_pro'), false);
        await _prefs?.setString(_key('plan'), ProPlanType.none.name);
        await _prefs?.setInt(_key('expiry'), 0);
      }
    }
  }

  void _resetInMemory() {
    _isPro = false;
    _planType = ProPlanType.none;
    _expiryTimestamp = 0;
  }

  String _normalizeAccountKey(String? login) =>
      (login ?? '').trim().toLowerCase();

  String _key(String suffix) {
    final encodedAccount = Uri.encodeComponent(_accountKey);
    return '${Constants.storageAccessToken}_${encodedAccount}_pro_$suffix';
  }

  ProPlanType _planFromString(String s) {
    return ProPlanType.values
        .firstWhere((e) => e.name == s, orElse: () => ProPlanType.none);
  }
}

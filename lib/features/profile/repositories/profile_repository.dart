import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> fetchProfile(String phone);
  Future<UserProfile> updateProfile(String phone, {required String fullName, String? email});
}

class NetworkProfileRepository implements ProfileRepository {
  static const String _keyProfilePrefix = 'payflow_cached_profile_';

  final ApiClient _apiClient;

  NetworkProfileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? defaultApiClient;

  @override
  Future<UserProfile> fetchProfile(String phone) async {
    final cleanPhone = phone.trim();

    try {
      final res = await _apiClient.get('/v1/users/$cleanPhone/profile');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final profile = UserProfile.fromJson(json);
        await _cacheProfile(cleanPhone, profile);
        return profile;
      }
    } catch (_) {}

    // Check cached profile in SharedPreferences
    final cached = await _getCachedProfile(cleanPhone);
    if (cached != null) {
      return cached;
    }

    // Honest fallback: never a fake name
    return UserProfile(
      phone: cleanPhone,
      displayName: 'User $cleanPhone',
      fullName: null,
      email: null,
    );
  }

  @override
  Future<UserProfile> updateProfile(
    String phone, {
    required String fullName,
    String? email,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = fullName.trim();
    final cleanEmail = email?.trim();

    try {
      final res = await _apiClient.put(
        '/v1/users/$cleanPhone/profile',
        body: {
          'fullName': cleanName,
          if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
        },
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final updated = UserProfile.fromJson(json);
        await _cacheProfile(cleanPhone, updated);
        return updated;
      }
    } catch (_) {}

    // Offline / fallback persistence
    final updated = UserProfile(
      phone: cleanPhone,
      displayName: cleanName,
      fullName: cleanName,
      email: cleanEmail,
    );
    await _cacheProfile(cleanPhone, updated);
    return updated;
  }

  Future<void> _cacheProfile(String phone, UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyProfilePrefix$phone', jsonEncode(profile.toJson()));
      // Also cache global keys for quick sync with AuthRepository
      if (profile.fullName != null) {
        await prefs.setString('payflow_user_fullname', profile.fullName!);
      }
      if (profile.email != null) {
        await prefs.setString('payflow_user_email', profile.email!);
      }
    } catch (_) {}
  }

  Future<UserProfile?> _getCachedProfile(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyProfilePrefix$phone');
      if (raw != null && raw.isNotEmpty) {
        return UserProfile.fromJson(jsonDecode(raw));
      }
      // Check if saved via AuthRepository during signup
      final savedName = prefs.getString('payflow_user_fullname');
      final savedEmail = prefs.getString('payflow_user_email');
      if (savedName != null && savedName.isNotEmpty) {
        return UserProfile(
          phone: phone,
          displayName: savedName,
          fullName: savedName,
          email: savedEmail,
        );
      }
    } catch (_) {}
    return null;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return NetworkProfileRepository();
});

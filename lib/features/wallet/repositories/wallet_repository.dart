import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../home/models/transaction_item.dart';

abstract class WalletRepository {
  Future<double?> getBalance();
  Future<List<TransactionItem>> getTransactions();
}

class ApiWalletRepository implements WalletRepository {
  final ApiClient _apiClient;
  double? _lastBalance;

  ApiWalletRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? defaultApiClient;

  @override
  Future<double?> getBalance() async {
    if (Env.isMockMode) return null;

    try {
      debugPrint('[WalletHydration] Fetching wallet balance...');
      var response = await _apiClient.get('/v1/wallet/balance/me');
      if (response.statusCode != 200) {
        response = await _apiClient.get('/v1/wallet/balance');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final koboBalance = (data['walletBalance'] as num?)?.toDouble() ??
            (data['balance'] as num?)?.toDouble() ??
            (data['balanceInKobo'] as num?)?.toDouble();

        if (koboBalance != null) {
          final naira = koboBalance / 100.0;
          _lastBalance = naira;
          debugPrint('[WalletHydration] Successfully retrieved balance: ₦$naira');
          return naira;
        }
      } else {
        debugPrint('[WalletHydration] Failed to fetch balance: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[WalletHydration] Exception fetching balance: $e');
    }
    return null;
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    if (Env.isMockMode) return [];

    try {
      final response = await _apiClient.get('/v1/wallet/transactions');
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];
        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final txns = decoded['transactions'];
          final data = decoded['data'];
          if (txns is List) {
            rawList = txns;
          } else if (data is List) {
            rawList = data;
          } else if (data is Map && data['transactions'] is List) {
            rawList = data['transactions'] as List;
          }
        }
        final transactions = rawList
            .map((item) => TransactionItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final balance = _lastBalance ?? 0.0;
        debugPrint('[WalletRepo] Loaded ${transactions.length} transactions, Balance:$balance');
        return transactions;
      }
    } catch (e) {
      debugPrint('[WalletRepository] Error fetching transactions: $e');
    }
    return [];
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return ApiWalletRepository();
});

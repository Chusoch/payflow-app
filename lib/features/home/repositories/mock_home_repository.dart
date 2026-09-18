import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/promo_banner.dart';
import '../models/transaction_item.dart';
import 'home_repository.dart';

class MockHomeRepository implements HomeRepository {
  @override
  Future<List<PromoBanner>> getPromoBanners() async {
    return const [
      PromoBanner(
        id: 'banner_1',
        title: 'Zero Fee Bank Transfers',
        subtitle: 'Enjoy 0% service charges on all local bank transfers this month.',
        badgeText: 'PROMO',
        gradientColors: [AppColors.primary, AppColors.primaryDark],
        icon: Icons.flash_on_rounded,
        actionRoute: '/transfer',
      ),
      PromoBanner(
        id: 'banner_2',
        title: 'Instant Naira Transfers',
        subtitle: 'Send money instantly to any Nigerian bank account 24/7.',
        badgeText: 'NAIRA',
        gradientColors: [Color(0xFF059669), Color(0xFF10B981)],
        icon: Icons.send_rounded,
        actionRoute: '/transfer',
      ),
      PromoBanner(
        id: 'banner_3',
        title: '100% Extra Airtime & Data',
        subtitle: 'Get double data value on your MTN and Airtel recharges via PayFlow.',
        badgeText: 'OFFER',
        gradientColors: [AppColors.secondary, Color(0xFF4F46E5)],
        icon: Icons.wifi_calling_3_rounded,
        actionRoute: '/services',
      ),
      PromoBanner(
        id: 'banner_4',
        title: 'Scan & Pay Rewards',
        subtitle: 'Earn up to 5% instant cashback when paying at partner merchant stores.',
        badgeText: 'NEW',
        gradientColors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        icon: Icons.qr_code_scanner_rounded,
      ),
    ];
  }

  @override
  Future<List<TransactionItem>> getRecentTransactions() async {
    return [
      TransactionItem(
        id: 'tx_1',
        title: 'Netflix Subscription',
        category: 'Entertainment',
        amount: 4500.00,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isCredit: false,
        status: 'Completed',
      ),
      TransactionItem(
        id: 'tx_2',
        title: 'Salary Deposit - TechCorp',
        category: 'Income',
        amount: 350000.00,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isCredit: true,
        status: 'Completed',
      ),
      TransactionItem(
        id: 'tx_3',
        title: 'Airtime Recharge (MTN)',
        category: 'Bills',
        amount: 2000.00,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isCredit: false,
        status: 'Completed',
      ),
      TransactionItem(
        id: 'tx_4',
        title: 'Supermarket Groceries',
        category: 'Shopping',
        amount: 18450.00,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isCredit: false,
        status: 'Completed',
      ),
    ];
  }
}


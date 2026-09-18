import '../models/promo_banner.dart';
import '../models/transaction_item.dart';

abstract class HomeRepository {
  Future<List<PromoBanner>> getPromoBanners();
  Future<List<TransactionItem>> getRecentTransactions();
}


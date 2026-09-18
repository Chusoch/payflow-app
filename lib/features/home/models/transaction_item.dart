enum TransactionType { credit, debit }

typedef Transaction = TransactionItem;

/// Returns the formatted transaction title with explicit directional narrative:
/// - User A (Debit / outflow): "Transfer to [Recipient Name]"
/// - User B (Credit / inflow): "Transfer from [Sender Name]"
String getTransactionTitle(Transaction txn, String currentUserId) {
  final cleanCurrent = currentUserId.trim().replaceAll('+', '');
  final cleanSender = txn.senderId?.trim().replaceAll('+', '');
  final cleanSenderPhone = txn.senderPhone?.trim().replaceAll('+', '');
  final isSenderMatch = cleanCurrent.isNotEmpty &&
      (cleanSender == cleanCurrent || cleanSenderPhone == cleanCurrent);

  final isOutgoing = isSenderMatch || txn.senderId == currentUserId || txn.type == TransactionType.debit;
  final category = txn.category.toLowerCase();
  if (category == 'transfer' || category == 'p2p_transfer' || category == 'bank_transfer') {
    if (isOutgoing) {
      final recipient = txn.recipientName?.trim().isNotEmpty == true
          ? txn.recipientName!.trim()
          : (txn.recipientOrSender?.trim().isNotEmpty == true ? txn.recipientOrSender!.trim() : 'Recipient');
      return 'Transfer to $recipient';
    } else {
      final sender = txn.senderName?.trim().isNotEmpty == true
          ? txn.senderName!.trim()
          : (txn.recipientOrSender?.trim().isNotEmpty == true ? txn.recipientOrSender!.trim() : 'Sender');
      return 'Transfer from $sender';
    }
  }
  return (txn.title.trim().isNotEmpty ? txn.title : null) ?? txn.description ?? 'Transaction';
}

class TransactionItem {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime timestamp;
  final bool isCredit;
  final String status;
  final String? reference;
  final String? recipientOrSender;
  final String? transferType;
  final String? token;
  final String? narration;
  final String? description;
  final String? senderId;
  final String? recipientId;
  final String? senderName;
  final String? recipientName;
  final String? senderPhone;
  final String? recipientPhone;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.timestamp,
    required this.isCredit,
    required this.status,
    this.reference,
    this.recipientOrSender,
    this.transferType,
    this.token,
    this.narration,
    this.description,
    this.senderId,
    this.recipientId,
    this.senderName,
    this.recipientName,
    this.senderPhone,
    this.recipientPhone,
  });

  TransactionType get type => isCredit ? TransactionType.credit : TransactionType.debit;

  /// Returns directional narrative formatted title for this transaction.
  String getFormattedTitle([String? currentUserId]) {
    if (currentUserId != null && currentUserId.isNotEmpty) {
      return getTransactionTitle(this, currentUserId);
    }
    final isOutgoing = !isCredit;
    final cat = category.toLowerCase();
    if (cat == 'transfer' || cat == 'p2p_transfer' || cat == 'bank_transfer') {
      if (isOutgoing) {
        final recipient = recipientName?.trim().isNotEmpty == true
            ? recipientName!.trim()
            : (recipientOrSender?.trim().isNotEmpty == true ? recipientOrSender!.trim() : 'Recipient');
        return 'Transfer to $recipient';
      } else {
        final sender = senderName?.trim().isNotEmpty == true
            ? senderName!.trim()
            : (recipientOrSender?.trim().isNotEmpty == true ? recipientOrSender!.trim() : 'Sender');
        return 'Transfer from $sender';
      }
    }
    return title.trim().isNotEmpty ? title : (description ?? 'Transaction');
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final num? naira = json['amountNaira'] as num?;
    final num? rawAmount = json['amount'] as num?;
    double parsedAmount = 0.0;

    if (naira != null) {
      parsedAmount = naira.toDouble();
    } else if (rawAmount != null) {
      if (json['amountInKobo'] != null || json['amount_kobo'] != null) {
        parsedAmount = rawAmount.toDouble() / 100.0;
      } else {
        parsedAmount = rawAmount.toDouble() / 100.0;
      }
    }

    final typeStr = (json['type'] ?? '').toString().toLowerCase();
    final isCredit = json['isCredit'] == true || typeStr == 'credit';

    DateTime parsedDate;
    try {
      final dateVal = json['createdAt'] ?? json['timestamp'];
      if (dateVal is DateTime) {
        parsedDate = dateVal;
      } else if (dateVal != null) {
        parsedDate = DateTime.parse(dateVal.toString());
      } else {
        parsedDate = DateTime.now();
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final rawSenderId = json['senderId']?.toString() ?? json['senderPhone']?.toString() ?? json['fromPhone']?.toString();
    final rawRecipientId = json['recipientId']?.toString() ?? json['recipientPhone']?.toString() ?? json['toPhone']?.toString();
    final rawSenderPhone = json['senderPhone']?.toString() ?? json['fromPhone']?.toString();
    final rawRecipientPhone = json['recipientPhone']?.toString() ?? json['toPhone']?.toString();

    String? resolvedSenderName = json['senderName']?.toString();
    String? resolvedRecipientName = json['recipientName']?.toString();
    final rawRecipientOrSender = json['recipientOrSender']?.toString();

    if (resolvedSenderName == null && isCredit && rawRecipientOrSender != null) {
      resolvedSenderName = rawRecipientOrSender;
    }
    if (resolvedRecipientName == null && !isCredit && rawRecipientOrSender != null) {
      resolvedRecipientName = rawRecipientOrSender;
    }

    final rawTitle = (json['title'] ?? '').toString().trim();
    if (resolvedRecipientName == null && rawTitle.startsWith('Transfer to ')) {
      resolvedRecipientName = rawTitle.substring('Transfer to '.length).trim();
    }
    if (resolvedSenderName == null && rawTitle.startsWith('Transfer from ')) {
      resolvedSenderName = rawTitle.substring('Transfer from '.length).trim();
    }

    final cat = (json['category'] ?? (isCredit ? 'Top Up' : 'Transfer')).toString();

    String finalTitle = rawTitle;
    if (finalTitle.isEmpty) {
      finalTitle = isCredit ? 'Credit' : 'Debit';
    }

    // If it's a transfer and we have counterparty information, ensure directional correctness
    final isTransferCategory = cat.toLowerCase() == 'transfer' || cat.toLowerCase() == 'p2p_transfer';
    if (isTransferCategory) {
      if (isCredit) {
        final sender = resolvedSenderName?.trim().isNotEmpty == true
            ? resolvedSenderName!.trim()
            : (rawRecipientOrSender?.trim().isNotEmpty == true ? rawRecipientOrSender!.trim() : 'Sender');
        finalTitle = 'Transfer from $sender';
      } else {
        final recipient = resolvedRecipientName?.trim().isNotEmpty == true
            ? resolvedRecipientName!.trim()
            : (rawRecipientOrSender?.trim().isNotEmpty == true ? rawRecipientOrSender!.trim() : 'Recipient');
        finalTitle = 'Transfer to $recipient';
      }
    }

    return TransactionItem(
      id: (json['id'] ?? json['reference'] ?? '').toString(),
      title: finalTitle,
      category: cat,
      amount: parsedAmount,
      timestamp: parsedDate,
      isCredit: isCredit,
      status: (json['status'] ?? 'Completed').toString(),
      reference: (json['reference'] ?? json['id'])?.toString(),
      recipientOrSender: rawRecipientOrSender ?? (isCredit ? resolvedSenderName : resolvedRecipientName),
      transferType: json['transferType']?.toString(),
      token: json['token']?.toString(),
      narration: (json['narration'] ?? json['description'])?.toString(),
      description: (json['description'] ?? json['narration'])?.toString(),
      senderId: rawSenderId,
      recipientId: rawRecipientId,
      senderName: resolvedSenderName,
      recipientName: resolvedRecipientName,
      senderPhone: rawSenderPhone,
      recipientPhone: rawRecipientPhone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': (amount * 100).toInt(),
      'amountNaira': amount,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': timestamp.toIso8601String(),
      'isCredit': isCredit,
      'type': isCredit ? 'credit' : 'debit',
      'status': status,
      'reference': reference,
      'recipientOrSender': recipientOrSender,
      'transferType': transferType,
      'token': token,
      'narration': narration,
      'description': description,
      'senderId': senderId,
      'recipientId': recipientId,
      'senderName': senderName,
      'recipientName': recipientName,
      'senderPhone': senderPhone,
      'recipientPhone': recipientPhone,
    };
  }
}

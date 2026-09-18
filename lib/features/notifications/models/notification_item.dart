enum NotificationCategory {
  transactions,
  security,
  promotions,
}

extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.transactions:
        return 'Transactions';
      case NotificationCategory.security:
        return 'Security';
      case NotificationCategory.promotions:
        return 'Promotions';
    }
  }

  String get channelId {
    switch (this) {
      case NotificationCategory.transactions:
        return 'transactions_channel';
      case NotificationCategory.security:
        return 'security_channel';
      case NotificationCategory.promotions:
        return 'promotions_channel';
    }
  }

  String get channelName {
    switch (this) {
      case NotificationCategory.transactions:
        return 'Transactions & Payments';
      case NotificationCategory.security:
        return 'Security & Account Alerts';
      case NotificationCategory.promotions:
        return 'Promotions & Updates';
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? payload;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => NotificationCategory.transactions,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}

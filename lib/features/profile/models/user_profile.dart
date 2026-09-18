class UserProfile {
  final String phone;
  final String displayName;
  final String? fullName;
  final String? email;

  const UserProfile({
    required this.phone,
    this.displayName = '',
    this.fullName,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      phone: (json['phone'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? (json['fullName'] as String?) ?? '',
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'displayName': displayName,
      'fullName': fullName,
      'email': email,
    };
  }

  UserProfile copyWith({
    String? phone,
    String? displayName,
    String? fullName,
    String? email,
  }) {
    return UserProfile(
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
    );
  }
}

class UserModel {
  final String? id;
  final String? phoneNumber;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? displayName;

  UserModel({
    this.id,
    this.phoneNumber,
    this.fullName,
    String? firstName,
    String? lastName,
    this.email,
    String? displayName,
  })  : firstName = firstName ?? _deriveFirst(fullName),
        lastName = lastName ?? _deriveLast(fullName),
        displayName = displayName ?? fullName;

  static String? _deriveFirst(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : null;
  }

  static String? _deriveLast(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['fullName'] as String?) ??
        (json['name'] as String?);

    final rawDisplayName = json['displayName'] as String?;
    final isSyntheticDisplayName = rawDisplayName != null &&
        RegExp(r'^User\s+(\+?\d+|null)?$', caseSensitive: false).hasMatch(rawDisplayName.trim());

    final rawFullName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (!isSyntheticDisplayName && rawDisplayName != null && rawDisplayName.trim().isNotEmpty
            ? rawDisplayName.trim()
            : null);

    return UserModel(
      id: (json['id'] ?? json['uid'] ?? json['phone']) as String?,
      phoneNumber: (json['phoneNumber'] ?? json['phone']) as String?,
      fullName: rawFullName,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      displayName: (!isSyntheticDisplayName && rawDisplayName != null && rawDisplayName.trim().isNotEmpty)
          ? rawDisplayName.trim()
          : rawFullName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (fullName != null) 'fullName': fullName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
    };
  }

  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? fullName,
    String? firstName,
    String? lastName,
    String? email,
    String? displayName,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, fullName: $fullName, firstName: $firstName, phone: $phoneNumber, email: $email)';
}

typedef User = UserModel;

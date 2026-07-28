class UserProfile {
  const UserProfile({
    this.name,
    this.email,
    this.mobile,
    this.userType,
    this.isBlocked = false,
    this.cancellationCount = 0,
    this.pendingCancellationFees = 0,
    this.profilePicture,
    this.accountStatus,
    this.isActive = true,
  });

  final String? name;
  final String? email;
  final String? mobile;
  final String? userType;
  final bool isBlocked;
  final int cancellationCount;
  final double pendingCancellationFees;
  final String? profilePicture;
  final String? accountStatus;
  final bool isActive;

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    return UserProfile(
      name: data['name'] as String?,
      email: data['email'] as String?,
      mobile: data['mobile'] as String?,
      userType: data['userType'] as String?,
      isBlocked: data['isBlocked'] as bool? ?? false,
      cancellationCount: _toInt(data['cancellationCount']),
      pendingCancellationFees: _toDouble(data['pendingCancellationFees']),
      profilePicture: data['profilePicture'] as String?,
      accountStatus: data['accountStatus'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (mobile != null) 'mobile': mobile,
        if (userType != null) 'userType': userType,
        'isBlocked': isBlocked,
        'cancellationCount': cancellationCount,
        'pendingCancellationFees': pendingCancellationFees,
        if (profilePicture != null) 'profilePicture': profilePicture,
        if (accountStatus != null) 'accountStatus': accountStatus,
        'isActive': isActive,
      };

  UserProfile copyWith({
    String? name,
    String? email,
    String? mobile,
    String? userType,
    bool? isBlocked,
    int? cancellationCount,
    double? pendingCancellationFees,
    String? profilePicture,
    String? accountStatus,
    bool? isActive,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      userType: userType ?? this.userType,
      isBlocked: isBlocked ?? this.isBlocked,
      cancellationCount: cancellationCount ?? this.cancellationCount,
      pendingCancellationFees: pendingCancellationFees ?? this.pendingCancellationFees,
      profilePicture: profilePicture ?? this.profilePicture,
      accountStatus: accountStatus ?? this.accountStatus,
      isActive: isActive ?? this.isActive,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0;
  }
}

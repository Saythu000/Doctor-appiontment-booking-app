class User {
  final String id;
  final String email;
  final String name;
  final String? image;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.image,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'image': image,
    };
  }
}

class UserSession {
  final String id;
  final String token;
  final String userId;
  final String? activeOrganizationId;
  final String expiresAt;

  UserSession({
    required this.id,
    required this.token,
    required this.userId,
    this.activeOrganizationId,
    required this.expiresAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'] as String,
      token: json['token'] as String,
      userId: json['userId'] as String,
      activeOrganizationId: json['activeOrganizationId'] as String?,
      expiresAt: json['expiresAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'userId': userId,
      'activeOrganizationId': activeOrganizationId,
      'expiresAt': expiresAt,
    };
  }
}

class GetSessionResponse {
  final UserSession session;
  final User user;

  GetSessionResponse({
    required this.session,
    required this.user,
  });

  factory GetSessionResponse.fromJson(Map<String, dynamic> json) {
    return GetSessionResponse(
      session: UserSession.fromJson(json['session'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

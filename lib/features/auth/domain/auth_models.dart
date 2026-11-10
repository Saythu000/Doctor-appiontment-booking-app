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

class OAuth2TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String tokenType;
  final int expiresIn;
  final String? scope;

  OAuth2TokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    required this.tokenType,
    required this.expiresIn,
    this.scope,
  });

  factory OAuth2TokenResponse.fromJson(Map<String, dynamic> json) {
    return OAuth2TokenResponse(
      accessToken: (json['access_token'] ?? json['accessToken'] ?? '').toString(),
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 3600,
      scope: json['scope'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'id_token': idToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'scope': scope,
    };
  }
}

class OAuth2AuthResult {
  final OAuth2TokenResponse tokens;
  final User user;
  final String? sessionJwt;
  final String? cookies;

  OAuth2AuthResult({
    required this.tokens,
    required this.user,
    this.sessionJwt,
    this.cookies,
  });
}


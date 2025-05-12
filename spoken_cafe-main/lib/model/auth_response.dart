class AuthResponse {
  final String? token;
  final String? error;

  AuthResponse({this.token, this.error});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? json['access_token'],
      error: json['error'] ?? json['message'],
    );
  }
}

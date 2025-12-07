class UserSession {
  static int? _userId;
  static String? _userName;
  static String? _userEmail;
  static String? _userPhone;

  // Set user session after login/signup
  static void setUser({
    required int userId,
    String? name,
    String? email,
    String? phone,
  }) {
    _userId = userId;
    _userName = name;
    _userEmail = email;
    _userPhone = phone;
    print('✅ User session set: userId=$userId, name=$name, email=$email');
  }

  // Get current user ID
  static int? getUserId() {
    return _userId;
  }

  // Check if user is logged in
  static bool isLoggedIn() {
    return _userId != null;
  }

  // Clear session on logout
  static void clearSession() {
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    print('🔐 User session cleared');
  }

  // Get user info
  static Map<String, dynamic>? getUserInfo() {
    if (_userId == null) return null;
    return {
      'userId': _userId,
      'name': _userName,
      'email': _userEmail,
      'phone': _userPhone,
    };
  }

  // Get user name
  static String? getUserName() {
    return _userName;
  }

  // Get user email
  static String? getUserEmail() {
    return _userEmail;
  }
}

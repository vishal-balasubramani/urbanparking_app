import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/api_config.dart';
import 'user_session.dart'; // ✅ ADD THIS

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  // Register with email/password
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);

        // ✅ SET USER SESSION
        UserSession.setUser(
          userId: data['user']['id'],
          name: data['user']['name'],
          email: data['user']['email'],
          phone: data['user']['phone'],
        );

        return data;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Registration failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Login with email/password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);

        // ✅ SET USER SESSION
        UserSession.setUser(
          userId: data['user']['id'],
          name: data['user']['name'],
          email: data['user']['email'],
          phone: data['user']['phone'],
        );

        return data;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Login failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Google Sign-In
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google sign-in cancelled by user';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('Google Sign-In successful:');
      print('Email: ${googleUser.email}');
      print('Name: ${googleUser.displayName}');
      print('ID: ${googleUser.id}');

      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'googleId': googleUser.id,
          'email': googleUser.email,
          'name': googleUser.displayName ?? 'User',
          'profilePic': googleUser.photoUrl,
          'idToken': googleAuth.idToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);

        // ✅ SET USER SESSION
        UserSession.setUser(
          userId: data['user']['id'],
          name: data['user']['name'],
          email: data['user']['email'],
          phone: data['user']['phone'],
        );

        return data;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Google sign-in failed on server';
      }
    } catch (e) {
      print('Google sign-in error: $e');
      try {
        await _googleSignIn.signOut();
      } catch (signOutError) {
        print('Sign out error: $signOutError');
      }
      throw 'Google sign-in error: ${e.toString()}';
    }
  }

  // Apple Sign-In
  Future<Map<String, dynamic>> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final fullName = credential.givenName != null && credential.familyName != null
          ? '${credential.givenName} ${credential.familyName}'
          : null;

      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/apple');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appleId': credential.userIdentifier,
          'email': credential.email,
          'name': fullName,
          'identityToken': credential.identityToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);

        // ✅ SET USER SESSION
        UserSession.setUser(
          userId: data['user']['id'],
          name: data['user']['name'],
          email: data['user']['email'],
          phone: data['user']['phone'],
        );

        return data;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Apple sign-in failed on server';
      }
    } catch (e) {
      print('Apple sign-in error: $e');
      throw 'Apple sign-in error: ${e.toString()}';
    }
  }

  // Get current user from server
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/me');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        await _saveUserData(user);

        // ✅ SET USER SESSION
        UserSession.setUser(
          userId: user['id'],
          name: user['name'],
          email: user['email'],
          phone: user['phone'],
        );

        return user;
      }
      return null;
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw 'Not authenticated';

      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/profile');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
        }),
      );

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        await _saveUserData(user);

        // ✅ UPDATE USER SESSION
        UserSession.setUser(
          userId: user['id'],
          name: user['name'],
          email: user['email'],
          phone: user['phone'],
        );

        return user;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Profile update failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Save auth data locally
  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // Save user data only
  Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // Get stored token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get stored user
  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google sign out error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    // ✅ CLEAR USER SESSION
    UserSession.clearSession();
  }

  // Get user ID
  Future<int?> getUserId() async {
    final user = await getStoredUser();
    return user?['id'];
  }

  // ✅ Load session from storage (call on app start)
  Future<void> loadSession() async {
    final user = await getStoredUser();
    if (user != null) {
      UserSession.setUser(
        userId: user['id'],
        name: user['name'],
        email: user['email'],
        phone: user['phone'],
      );
    }
  }
}

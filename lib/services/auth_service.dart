import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Fixed: Add serverClientId if you need serverAuthCode
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
    // Optional: Only add serverClientId if you need serverAuthCode
    // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
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
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw error['error'] ?? 'Login failed';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Google Sign-In (Fixed for v7.x)
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Sign out first to force account picker
      await _googleSignIn.signOut();

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw 'Google sign-in cancelled by user';
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Debug log
      print('Google Sign-In successful:');
      print('Email: ${googleUser.email}');
      print('Name: ${googleUser.displayName}');
      print('ID: ${googleUser.id}');
      print('ID Token: ${googleAuth.idToken}');

      // Send to backend (REMOVED serverAuthCode - not needed for basic auth)
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

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);
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

      print('Apple Sign-In successful:');
      print('Email: ${credential.email}');
      print('Name: $fullName');
      print('ID: ${credential.userIdentifier}');

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

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveAuthData(data['token'], data['user']);
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
  }

  // Get user ID
  Future<int?> getUserId() async {
    final user = await getStoredUser();
    return user?['id'];
  }
}

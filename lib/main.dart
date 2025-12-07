import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:urban_parking_app/services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/parking_list_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.loadSession();

  // Set status bar to light content (white icons)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF1A1A1F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const UrbParkApp());
}

class UrbParkApp extends StatelessWidget {
  const UrbParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbPark - Smart Parking',
      debugShowCheckedModeBanner: false,
      theme: _buildUrbParkTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/landing': (context) => const LandingScreen(),
        '/auth': (context) => const AuthScreen(),
        '/parking-list': (context) => const ParkingListScreen(),
      },
    );
  }

  ThemeData _buildUrbParkTheme() {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF5C63B),
        primary: const Color(0xFFF5C63B),
        secondary: const Color(0xFF4ADE80),
        tertiary: const Color(0xFFFF6B35),
        surface: const Color(0xFF2D2D33),
        background: const Color(0xFF1A1A1F),
        error: const Color(0xFFEF4444),
        onPrimary: const Color(0xFF1A1A1F),
        onSecondary: Colors.white,
        onBackground: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFFFFFFFF),
        brightness: Brightness.dark,
      ),

      // Scaffold
      scaffoldBackgroundColor: const Color(0xFF1A1A1F),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1F),
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFFFFFF),
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(
          color: Color(0xFFFFFFFF),
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: const Color(0xFF2D2D33),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF5C63B),
          foregroundColor: const Color(0xFF1A1A1F),
          elevation: 2,
          shadowColor: const Color(0xFFF5C63B).withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF5C63B),
          side: const BorderSide(
            color: Color(0xFFF5C63B),
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D33),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF5C63B), width: 2),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF8D8D93),
          fontSize: 15,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF52525B),
          fontSize: 15,
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFFF5C63B),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF2D2D33),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2D2D33),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFFFFFFFF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

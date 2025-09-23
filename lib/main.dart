import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recoveryplus/providers/theme_provider.dart';
import 'package:recoveryplus/screens/auth_screen.dart';
import 'package:recoveryplus/screens/home_screen.dart';
import 'package:recoveryplus/services/auth_service.dart';
import 'package:recoveryplus/services/notification_service.dart';
import 'package:recoveryplus/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:recoveryplus/services/database_service.dart'; // Added import
import 'package:recoveryplus/models/appointment.dart'; // Added import
import 'package:cloud_firestore/cloud_firestore.dart'; // Added import
import 'package:recoveryplus/utils/boot_events_handler.dart'; // Added import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  debugPrint('Firebase initialized. Current user: ${FirebaseAuth.instance.currentUser?.uid}');

  final notificationService = NotificationService();
  await notificationService.initialize();

  final authService = AuthService(); // Create AuthService instance here

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const RecoveryPlusApp(),
    ),
  );
}

class RecoveryPlusApp extends StatelessWidget {
  const RecoveryPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building RecoveryPlusApp');
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final baseLight = AppTheme.lightTheme;
        final baseDark = AppTheme.darkTheme;

        ThemeData lightTheme = baseLight.copyWith(
          appBarTheme: baseLight.appBarTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.secondary : baseLight.colorScheme.secondary,
            foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
          ),
          bottomNavigationBarTheme: baseLight.bottomNavigationBarTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
            selectedItemColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
            unselectedItemColor: (themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary).withOpacity(0.6),
          ),
          floatingActionButtonTheme: baseLight.floatingActionButtonTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.secondary : baseLight.colorScheme.secondary,
            foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onSecondary : baseLight.colorScheme.onSecondary,
          ),
          dialogTheme: baseLight.dialogTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.background : baseLight.colorScheme.background,
            titleTextStyle: (themeProvider.isDarkMode ? baseDark : baseLight).textTheme.titleLarge?.copyWith(color: themeProvider.isDarkMode ? baseDark.colorScheme.onBackground : baseLight.colorScheme.onBackground),
            contentTextStyle: (themeProvider.isDarkMode ? baseDark : baseLight).textTheme.bodyMedium?.copyWith(color: themeProvider.isDarkMode ? baseDark.colorScheme.onBackground : baseLight.colorScheme.onBackground),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
              foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
            ),
          ),
        );

        ThemeData darkTheme = baseDark.copyWith(
          appBarTheme: baseDark.appBarTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.secondary : baseLight.colorScheme.secondary,
            foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
          ),
          bottomNavigationBarTheme: baseDark.bottomNavigationBarTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
            selectedItemColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
            unselectedItemColor: (themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary).withOpacity(0.6),
          ),
          floatingActionButtonTheme: baseDark.floatingActionButtonTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.secondary : baseLight.colorScheme.secondary,
            foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onSecondary : baseLight.colorScheme.onSecondary,
          ),
          dialogTheme: baseDark.dialogTheme.copyWith(
            backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.background : baseLight.colorScheme.background,
            titleTextStyle: (themeProvider.isDarkMode ? baseDark : baseLight).textTheme.titleLarge?.copyWith(color: themeProvider.isDarkMode ? baseDark.colorScheme.onBackground : baseLight.colorScheme.onBackground),
            contentTextStyle: (themeProvider.isDarkMode ? baseDark : baseLight).textTheme.bodyMedium?.copyWith(color: themeProvider.isDarkMode ? baseDark.colorScheme.onBackground : baseLight.colorScheme.onBackground),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.primary : baseLight.colorScheme.primary,
              foregroundColor: themeProvider.isDarkMode ? baseDark.colorScheme.onPrimary : baseLight.colorScheme.onPrimary,
            ),
          ),
        );

        return MaterialApp(
          title: 'Recovery Plus',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          supportedLocales: const [Locale('en', 'US'), Locale('es', 'ES')],
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _bootEventsHandled = false;

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (!_bootEventsHandled) {
          _bootEventsHandled = true;

          Future.microtask(() async {
            final prefs = await SharedPreferences.getInstance();
            String? lastLoggedInUid;

            if (user != null) {
              // Store current user's UID
              lastLoggedInUid = user.uid;
              await prefs.setString('lastLoggedInUid', lastLoggedInUid);
            } else {
              // Retrieve last logged-in UID
              lastLoggedInUid = prefs.getString('lastLoggedInUid');
            }

            // Only call handleBootEvents if we have a UID
            if (lastLoggedInUid != null && lastLoggedInUid.isNotEmpty) {
              await handleBootEvents(notificationService, authService);
            }
          });
        }

        if (user == null) {
          return AuthScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
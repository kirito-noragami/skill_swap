import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';


// استيراد الشاشات والخدمات
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/auth/login_screen.dart'; // سننشئها
import 'screens/home/home_screen.dart';   // سننشئها

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SkillSwap',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

// كلاس صغير يقرر: هل نذهب للرئيسية أم تسجيل الدخول؟
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.currentUser != null 
          ? FirebaseAuth.instance.authStateChanges() 
          : null, // تبسيط
      builder: (context, snapshot) {
        if (FirebaseAuth.instance.currentUser != null) {
          return const HomeScreen(); // سنبنيها
        }
        return const LoginScreen(); // سنبنيها
      },
    );
  }
}
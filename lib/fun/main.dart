import 'package:app1/fun/home_page.dart';
import 'package:flutter/material.dart';
import 'package:app1/fun/login_page.dart';
import 'package:app1/fun/register_page.dart';
import 'package:app1/fun/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../fun/word_provider.dart'; // 確保只從這個文件導入
import 'package:app1/fun/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:app1/fun/splash_page.dart';
import 'package:flutter/material.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 初始化 Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase 初始化失敗時的錯誤處理
    print("Firebase initialization failed: $e");
    return;  // 如果初始化失敗，就不執行後面的代碼
  }
  final wordProvider = WordProvider();
  await wordProvider.initializeWords();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => wordProvider), // ⭐ 用載好資料的 wordProvider
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MyApp(), // ⬅️ 一定要加上這行！
    ),
  );
}

final FirebaseFirestore db = FirebaseFirestore.instance;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '登入系統',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/splash', // 設定初始頁面為登入頁
      routes: {
        '/splash': (context) => SplashPage(),
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/profile': (context) => ProfilePage(),
        '/home': (context) => HomePage1(), // 當用戶登入後顯示個人資料頁面
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

void fetchUserRecord(String uid) async {
  // 這裡可以根據 uid 來獲取用戶的資料
  try {
    print("Fetching data for user: $uid");

    // 從 Firebase Firestore 獲取使用者紀錄
    DocumentSnapshot userDoc = await db.collection('users').doc(uid).get();

    if (userDoc.exists) {
      print("User data: ${userDoc.data()}");
      // 在這裡處理從 Firestore 讀取的資料
    } else {
      print("No user found with UID: $uid");
    }
  } catch (e) {
    print("Error fetching user data: $e");
  }
}

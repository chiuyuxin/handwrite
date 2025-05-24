import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'package:app1/fun/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../fun/user_provider.dart';


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firebase登入邏輯
  void login(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('錯誤'),
          content: Text('請輸入Email與密碼'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('確定')),
          ],
        ),
      );
      return;
    }

    final db = FirebaseFirestore.instance;

    try {
      // 使用 Firebase Authentication 進行登入
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUid(userCredential.user!.uid);

      User? user = userCredential.user;

      if (user != null) {
        // 取得使用者資料，並顯示到畫面
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final account = userDoc['username']; // ✅ 從 Firestore 拿帳號
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', account); // ✅ 儲存帳號
          await prefs.setBool('isGuest', false);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage1()),
        );
      } else {
        // 登入失敗
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('登入失敗'),
            content: Text('帳號或密碼錯誤'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('確定')),
            ],
          ),
        );
      }
    } catch (e) {
      print("登入錯誤：$e");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('登入'),
          content: Text('登入失敗'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('確定')),
          ],
        ),
      );
    }
  }


  // 訪客登入邏輯
  void guestLogin(BuildContext context) async {
    // 儲存：訪客登入
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGuest', true);  // 設定為訪客用戶

    // 跳轉到主頁
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage1()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登入'),
        backgroundColor: Colors.blue.shade100, // 設定 AppBar 顏色
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 帳號輸入框
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.black),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            // 密碼輸入框
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密碼',
                labelStyle: TextStyle(color: Colors.black),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            // 登入按鈕
            ElevatedButton(
              onPressed: () => login(context),
              child: Text('登入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade100, // 設定按鈕背景顏色
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12), // 設定按鈕內邊距
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 設定圓角
              ),
            ),
            SizedBox(height: 10),
            // 註冊按鈕
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegisterPage()),
              ),
              child: Text('還沒有帳號？點這裡註冊'),
            ),
            SizedBox(height: 10),
            // 訪客身份登入按鈕
            TextButton(
              onPressed: () => guestLogin(context), // 按下後跳轉到 HomePage1
              child: Text('以訪客身份進入'),
            ),
          ],
        ),
      ),
    );
  }
}

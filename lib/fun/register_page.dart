import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app1/fun/user_provider.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController accountController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  bool isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> register() async {
    final account = accountController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (account.isEmpty || email.isEmpty || password.isEmpty) {
      _showErrorDialog('請輸入帳號、Email和密碼');
      return;
    }

    if (!isPasswordValid(password)) {
      _showErrorDialog('密碼必須包含英文和數字，長度至少為8個字元');
      return;
    }

    setState(() => isLoading = true);

    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      final accountQuery =
      await db.collection("users").where('username', isEqualTo: account).get();
      final emailQuery =
      await db.collection("users").where('email', isEqualTo: email).get();

      if (accountQuery.docs.isNotEmpty) {
        _showErrorDialog('使用者名稱已被使用，請選擇其他名稱');
        return;
      }
      if (emailQuery.docs.isNotEmpty) {
        _showErrorDialog('Email 已被註冊，請使用其他信箱');
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await migrateGuestDataToUser(user.uid);

        await db.collection("users").doc(user.uid).set({
          'username': account,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUid(user.uid);
        userProvider.setUsername(account);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', account);
        await prefs.setBool('isGuest', false);

        final doc = await db.collection("users").doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('savedCharacters')) {
          final List<String> savedFromDb =
          List<String>.from(doc.data()!['savedCharacters']);
          await prefs.setStringList('saved', savedFromDb);
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('會員註冊'),
            content: Text('註冊成功！'),
            actions: [
              TextButton(
                onPressed: () async {
                  await Future.delayed(Duration(milliseconds: 300)); // ✅ 確保資料寫入完才跳轉
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
                child: Text('確定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("註冊失敗：$e");
      _showErrorDialog('註冊失敗，請稍後再試！');
    } finally {
      setState(() => isLoading = false);
    }
  }


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> migrateGuestDataToUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();

// ✅ 加入 scoreHistory 的轉移（避免挑戰頁載入後總分為 0）
    List<String> history = prefs.getStringList('scoreHistory_guest') ?? [];
    final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));

    for (var record in history) {
      final parts = record.split('|');
      if (parts.length != 2) continue;

      final score = int.tryParse(parts[0]) ?? 0;
      final time = DateTime.tryParse(parts[1]);

      if (time != null && time.isAfter(sevenDaysAgo)) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('scoreHistory')
            .add({
          'score': score,
          'timestamp': time.toIso8601String(),
        });
      }
    }
    await prefs.remove('scoreHistory_guest');

    // 讀 Guest 收藏和積分
    List<String> guestSaved = prefs.getStringList('saved_guest') ?? [];
    int guestScore = prefs.getInt('totalScore_guest') ?? 0;

    // 準備要寫入 Firebase 的學習紀錄
    Map<String, dynamic> recordsToTransfer = {};

    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('guest_') &&
          (key.endsWith('_correct') || key.endsWith('_incorrect'))) {
        final value = prefs.getInt(key);
        final regex = RegExp(r'^guest_(.+)_(correct|incorrect)$');
        final match = regex.firstMatch(key);
        if (value != null && match != null) {
          final character = match.group(1)!;
          final type = match.group(2)!;

          recordsToTransfer[character] ??= {};
          recordsToTransfer[character][type] = value;
        }
        await prefs.remove(key); // ❗ 清除 guest 記錄
      }
    }

// ✅ 移出來：只設定一次
    await prefs.setBool('forceRefreshScore', true);

    // 寫入 Firebase
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'savedCharacters': guestSaved,
      'totalScore': guestScore,
      'records': recordsToTransfer,
    }, SetOptions(merge: true));
    await prefs.setInt('totalScore_${uid}', guestScore);

    // 清除本地 guest 收藏與積分（不再寫入 UID 本地）
    await prefs.remove('saved_guest');
    await prefs.remove('totalScore_guest');

    await prefs.remove('username');
    await prefs.remove('isGuest');
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: accountController,
              decoration: InputDecoration(labelText: '使用者名稱'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: '密碼(包含英文和數字，長度至少為8個字元)'),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: register,
              child: Text('註冊'),
            ),
          ],
        ),
      ),
    );
  }
}

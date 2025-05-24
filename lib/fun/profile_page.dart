import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app1/fun/RankPage.dart'; // ⭐ 要記得有 RankPage

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _avatarUrl;
  bool isGuest = true;
  String userName = "小明";
  int _totalScore = 0; // ⭐ 累積積分
  List<Map<String, dynamic>> userRecords = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTotalScore();
  }

  Future<void> _loadTotalScore() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          int score = data?['totalScore'] ?? 0;
          setState(() {
            _totalScore = score;
          });
          await prefs.setInt('totalScore_${user.uid}', score); // 本地也存一份
        }
      } catch (e) {
        print('從 Firebase 載入積分失敗: $e');
        // 撈失敗就用本地資料
        setState(() {
          _totalScore = prefs.getInt('totalScore_${user.uid}') ?? 0;
        });
      }
    } else {
      // 訪客：只從本地拿
      setState(() {
        _totalScore = prefs.getInt('totalScore_guest') ?? 0;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuestLogin = prefs.getBool('isGuest') ?? true;
    final savedUsername = prefs.getString('username');
    final savedAvatarUrl = prefs.getString('avatarUrl');

    setState(() {
      _avatarUrl = savedAvatarUrl;
    });

    if (isGuestLogin || savedUsername == null) {
      setState(() {
        isGuest = true;
        userName = _generateRandomName();
        userRecords = [];
      });
    } else {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: savedUsername)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          isGuest = false;
          userName = data['username'] ?? savedUsername;
          userRecords = List<Map<String, dynamic>>.from(data['records'] ?? []);
          _avatarUrl = data['avatarUrl'] ?? _avatarUrl;
        });
      } else {
        setState(() {
          isGuest = false;
          userName = savedUsername;
          userRecords = [];
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      await _uploadAvatar(file);
    }
  }

  Future<void> _uploadAvatar(File file) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(file);

      final url = await ref.getDownloadURL();
      await _firestore.collection('users').doc(user.uid).update({
        'avatarUrl': url,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatarUrl', url);

      setState(() {
        _avatarUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('頭像更新成功！')),
      );
    } catch (e) {
      print('上傳頭像錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗，請稍後再試')),
      );
    }
  }

  Future<void> _editUsername() async {
    final TextEditingController newNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('修改使用者名稱'),
          content: TextField(
            controller: newNameController,
            decoration: InputDecoration(hintText: "輸入新名稱"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final newName = newNameController.text.trim();
                if (newName.isNotEmpty) {
                  await _updateUsername(newName);
                }
                Navigator.pop(context);
              },
              child: Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUsername(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;

      if (user != null) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: newName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('名稱已被使用，請更換一個！')),
          );
          return;
        }

        await _firestore.collection('users').doc(user.uid).update({
          'username': newName,
        });

        await prefs.setString('username', newName);

        setState(() {
          userName = newName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('名稱修改成功！')),
        );
      }
    } catch (e) {
      print('更新名稱錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改失敗，請稍後再試')),
      );
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      isGuest = true;
      userName = _generateRandomName();
      userRecords = [];
      _avatarUrl = null;
    });

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (Route<dynamic> route) => false,
    );
  }

  String _generateRandomName() {
    int guestNumber = Random().nextInt(100) + 1;
    return "Guest$guestNumber";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              Stack(
                children: [
                  GestureDetector(
                    onTap: isGuest ? null : _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
                          ? Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                  ),
                  if (!isGuest)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 16, color: Colors.blue),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "使用者名稱：$userName",
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (!isGuest)
                    IconButton(
                      icon: Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: _editUsername,
                    ),
                ],
              ),


              if (!isGuest) ...[
                const SizedBox(height: 10),
                Text(
                  "挑戰累積積分：$_totalScore 分",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 30),

              if (isGuest)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text("註冊帳號"),
                ),

              if (!isGuest)
                ElevatedButton(
                  onPressed: _logout,
                  child: const Text("登出"),
                ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RankPage()),
                  );
                },
                child: Text("查看排行榜"),
              ),

              if (!isGuest && userRecords.isNotEmpty) ...[
                const SizedBox(height: 30),
                const Text("使用紀錄", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...userRecords.map((r) => Text(
                  "字：${r['character']} - ${r['correct'] ? "正確" : "錯誤"}",
                  style: const TextStyle(fontSize: 16),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

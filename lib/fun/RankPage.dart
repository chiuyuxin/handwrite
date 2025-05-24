import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';


class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  _RankPageState createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  List<Map<String, dynamic>> _rankList = [];
  int? myRank;
  int? myScore;
  String myUsername = "";

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  Future<void> _loadRank() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      final uid = user?.uid;

      final prefs = await SharedPreferences.getInstance();
      final isGuest = prefs.getBool('isGuest') ?? true;
      final localUsername = prefs.getString('username') ?? "訪客";

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalScore', descending: true)
          .get();

      final List<Map<String, dynamic>> rankData = [];
      int currentRank = 1;
      int? foundRank;
      int? foundScore;
      String foundUsername = "";

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final username = data['username'] ?? '未知';
        final score = data['totalScore'] ?? 0;

        rankData.add({
          'username': username,
          'score': score,
          'uid': doc.id,
        });

        if (!isGuest && doc.id == uid) { // ⚡ 註冊會員才用 Firebase uid 對比
          foundRank = currentRank;
          foundScore = score;
          foundUsername = username;
        }

        currentRank++;
      }

      // 如果是訪客，自己補上
      if (isGuest) {
        foundRank = null; // 訪客沒有正式排名
        foundScore = prefs.getInt('totalScore_guest') ?? 0;
        foundUsername = localUsername;
      }

      setState(() {
        _rankList = rankData.take(20).toList(); // 顯示前20名
        myRank = foundRank;
        myScore = foundScore;
        myUsername = foundUsername;
      });
    } catch (e) {
      print('載入排行榜錯誤: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('挑戰排行榜')),
      body: _rankList.isEmpty
          ? Center(child: Text("尚無排行榜資料", style: TextStyle(fontSize: 20)))
          : ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (myRank != null)
            Card(
              color: Colors.lightBlue.shade50,
              child: ListTile(
                leading: Icon(Icons.person_pin, color: Colors.blueAccent, size: 40),
                title: Text('你的目前排名(7天重新計算排名)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '$myUsername - 第 $myRank 名（${myScore ?? 0} 分）',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          SizedBox(height: 20),
          ..._rankList.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> user = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('#${index + 1}'),
                  backgroundColor: index == 0
                      ? Colors.amber
                      : index == 1
                      ? Colors.grey
                      : index == 2
                      ? Colors.brown
                      : Colors.blueAccent,
                ),
                title: Text(user['username'], style: TextStyle(fontSize: 18)),
                trailing: Text('${user['score']} 分', style: TextStyle(fontSize: 18)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

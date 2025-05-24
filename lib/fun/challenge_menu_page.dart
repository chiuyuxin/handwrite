import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:app1/fun/word_provider.dart';
import 'package:app1/fun/challenge_game_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeMenuPage extends StatefulWidget {
  const ChallengeMenuPage({super.key});

  @override
  _ChallengeMenuPageState createState() => _ChallengeMenuPageState();
}

class _ChallengeMenuPageState extends State<ChallengeMenuPage> {
  int _totalScore = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalScore();
  }

  Future<void> _loadTotalScore() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final isGuest = prefs.getBool('isGuest') ?? false;

    final totalKey =
        user != null && !isGuest
            ? 'totalScore_${user.uid}'
            : 'totalScore_guest';
    final lastUpdateKey =
        user != null && !isGuest
            ? 'lastUpdate_${user.uid}'
            : 'lastUpdate_guest';

    final lastUpdateString = prefs.getString(lastUpdateKey);
    final lastUpdate =
        lastUpdateString != null ? DateTime.tryParse(lastUpdateString) : null;

    final forceRefresh = prefs.getBool('forceRefreshScore') ?? false;

    if (!forceRefresh &&
        lastUpdate != null &&
        now.difference(lastUpdate).inDays < 7) {
      setState(() {
        _totalScore = prefs.getInt(totalKey) ?? 0;
      });
      return;
    }

    int total = 0;
    final sevenDaysAgo = now.subtract(Duration(days: 7));

    if (user != null && !isGuest) {
      try {
        final snapshots =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('scoreHistory')
                .get();

        for (var doc in snapshots.docs) {
          final data = doc.data();
          final timestampStr = data['timestamp'];
          final scoreRaw = data['score'];

          final time = DateTime.tryParse(timestampStr ?? '');
          if (time != null && time.isAfter(sevenDaysAgo) && scoreRaw is num) {
            total += scoreRaw.toInt();
          }
        }
      } catch (e) {
        print('Firebase 讀取失敗：$e');
      }
    } else {
      final historyJson = prefs.getStringList('scoreHistory_guest') ?? [];
      for (var record in historyJson) {
        final parts = record.split('|');
        if (parts.length != 2) continue;
        final score = int.tryParse(parts[0]) ?? 0;
        final time = DateTime.tryParse(parts[1]);
        if (time != null && time.isAfter(sevenDaysAgo)) {
          total += score;
        }
      }
    }

    await prefs.setInt(totalKey, total);
    await prefs.setString(lastUpdateKey, now.toIso8601String());

    if (forceRefresh) {
      await prefs.remove('forceRefreshScore');
    }

    setState(() {
      _totalScore = total;
    });
  }

  Future<void> _updateTotalScore(int addedScore) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final isGuest = prefs.getBool('isGuest') ?? false;

    if (user != null && !isGuest) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final doc = await docRef.get();
        int currentScore = doc.exists ? (doc.data()?['totalScore'] ?? 0) : 0;
        final newScore = currentScore + addedScore;

        await docRef.set({'totalScore': newScore}, SetOptions(merge: true));
        await docRef.collection('scoreHistory').add({
          'score': addedScore,
          'timestamp': now.toIso8601String(),
        });

        await prefs.setInt('totalScore_${user.uid}', newScore);
      } catch (e) {
        print('儲存 Firebase 積分失敗: $e');
      }
    } else {
      int currentScore = prefs.getInt('totalScore_guest') ?? 0;
      await prefs.setInt('totalScore_guest', currentScore + addedScore);

      List<String> history = prefs.getStringList('scoreHistory_guest') ?? [];
      history.add('$addedScore|${now.toIso8601String()}');
      await prefs.setStringList('scoreHistory_guest', history);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCharacters = Provider.of<WordProvider>(context).words;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '累積積分',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '$_totalScore 分',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
          Text(
            '挑戰模式',
            style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          SizedBox(
            child: ElevatedButton.icon(
              icon: Icon(Icons.timer),
              label: Text("60 秒挑戰", style: TextStyle(fontSize: 30,color: Color(0xFF124E78))),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChallengeGamePage(
                          allCharacters: allCharacters,
                          onGameEnd: (score) async {
                            await _updateTotalScore(score);
                            await _loadTotalScore();
                          },
                        ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.sports_esports),
            label: Text("接蘋果", style: TextStyle(fontSize: 30,color: Color(0xFF124E78))),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChallengeCatchGamePage(
                        onGameEnd: (score) async {
                          await _updateTotalScore(score);
                          await _loadTotalScore();
                        },
                      ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.sports_esports),
            label: Text("打地鼠 - 找部首的小貓", style: TextStyle(fontSize: 30,color: Color(0xFF124E78))),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => WhacAMolePage(
                        onGameEnd: (score) async {
                          await _updateTotalScore(score);
                          await _loadTotalScore();
                        },
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

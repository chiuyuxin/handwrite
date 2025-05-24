import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WordCardData {
  final String word;
  final String id;
  final String pinyin;
  final String zhuyin;
  final String radical;
  final String strokes;
  final String meaning;
  final String polyphone;

  WordCardData({
    required this.word,
    required this.id,
    required this.pinyin,
    required this.zhuyin,
    required this.radical,
    required this.strokes,
    required this.meaning,
    required this.polyphone,
  });

  // 從 JSON 轉換為 WordCardData
  factory WordCardData.fromJson(Map<String, dynamic> json) {
    return WordCardData(
      word: json["word"] ?? " ",
      id: json["id"] ?? " ",
      pinyin: json["pinyin"] ?? " ",
      zhuyin: json["zhuyin"] ?? " ",
      radical: json["radical"]?.trim() ?? "無",
      strokes: json["strokes"] ?? "0",
      meaning: (json["meaning"] ?? "無").replaceAll("\n", " "),
      // 將換行符號替換為空格
      polyphone: json["polyphone"] ?? "無",
    );
  }
}


// 用來儲存 char 物件的範例資料
Map<String, dynamic> char = {};

// 初始化 WordCardData 物件
WordCardData data = WordCardData.fromJson(char);

// 統計頁面
class StatsPage extends StatelessWidget {
  final List<Map<String, String>> allCharacters;

  const StatsPage({required this.allCharacters});

  Future<Map<String, Map<String, int>>> loadAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "guest";

    Map<String, Map<String, int>> stats = {};

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final recordData = doc.data()?['records'] ?? {};
        for (var char in allCharacters) {
          final word = char['word']!;
          final data = recordData[word];
          final correct = data?['correct'] ?? 0;
          final incorrect = data?['incorrect'] ?? 0;
          stats[word] = {'correct': correct, 'incorrect': incorrect};
        }
        return stats;
      } catch (e) {
        print("從 Firebase 載入紀錄失敗，改用本地：$e");
      }
    }

    // fallback：訪客或 Firebase 無法使用時讀 SharedPreferences
    for (var char in allCharacters) {
      final word = char['word']!;
      final correct = prefs.getInt('${uid}_${word}_correct') ?? 0;
      final incorrect = prefs.getInt('${uid}_${word}_incorrect') ?? 0;
      stats[word] = {'correct': correct, 'incorrect': incorrect};
    }

    return stats;
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, int>>>( // 處理統計資料顯示
      future: loadAllStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final sortedStats = stats.entries.toList()
          ..sort((a, b) =>
              ((b.value['correct'] ?? 0) + (b.value['incorrect'] ?? 0))
                  .compareTo((a.value['correct'] ?? 0) +
                  (a.value['incorrect'] ?? 0)));

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: sortedStats.length,
          itemBuilder: (context, index) {
            final word = sortedStats[index].key;
            final correct = sortedStats[index].value['correct']!;
            final incorrect = sortedStats[index].value['incorrect']!;
            final total = correct + incorrect;
            final accuracy =
            total > 0 ? (correct / total * 100).toStringAsFixed(1) : '0.0';

            return Card(
              color: Color(0xFF90DBF4),
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('字：$word', style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('✅ $correct 次, ❌ $incorrect 次\n正確率：$accuracy%', style: TextStyle(fontSize: 30)),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlashcardScreen(
                                allCharacters: allCharacters,
                                initialWord: word, // 傳遞選中的字詞
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.auto_stories,color: Color(0xFF124E78),size: 35),
                        label: Text("查看字卡",style: TextStyle(fontSize: 30, color: Color(0xFF124E78))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 字卡頁面
class FlashcardScreen extends StatefulWidget {
  final List<Map<String, String>> allCharacters;
  final String initialWord; // 接收傳遞的字詞

  const FlashcardScreen({
    required this.allCharacters,
    required this.initialWord,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<WordCardData> _cards = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  void loadCards() {
    setState(() {
      _cards = widget.allCharacters
          .where((char) => char["word"] == widget.initialWord) // 過濾字卡
          .map((char) {
        print("Loading char: $char");
        return WordCardData(
          word: char["word"] ?? " ",
          id: char["id"] ?? " ",
          pinyin: char["pinyin"] ?? " ",
          zhuyin: char["zhuyin"] ?? " ",
          radical: char["radical"] ?? " ",
          strokes: char["strokes"] ?? " ",
          meaning: char["meaning"] ?? " ",
          polyphone: char["polyphone"] ?? " ",
        );
      }).toList();
    });
  }

  void nextCard() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _cards.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = _cards.isNotEmpty ? _cards[_currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('生字小卡', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:Color(0xFF90DBF4),
        centerTitle: true,
      ),
      body: Center(
        child: currentCard == null
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlipCard(data: currentCard),  // 顯示翻轉字卡
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// 可翻轉的字卡元件
class FlipCard extends StatefulWidget {
  final WordCardData data;

  const FlipCard({required this.data});

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  bool _isFront = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isFront = !_isFront),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          final rotate = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final isUnder = (child?.key != ValueKey(_isFront));
              final angle = isUnder ? pi - rotate.value : rotate.value;
              return Transform(
                transform: Matrix4.rotationY(angle),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: _isFront ? _buildFront() : _buildBack(),
      ),
    );
  }

  Widget _buildFront() =>
      Container(
        key: ValueKey(true),
        width: 350,
        height: 400,
        decoration: BoxDecoration(
          color: Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            widget.data.word,
            style: TextStyle(fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF9800)),
          ),
        ),
      );

  Widget _buildBack() {
    print(widget.data.toString());
    return Container(
      key: ValueKey(false),
      width: 350,
      height: 400,
      decoration: BoxDecoration(
        color: Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      padding: EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "注音：${widget.data.zhuyin}", style: TextStyle(fontSize: 20)),
              Text(
                  "拼音：${widget.data.pinyin}", style: TextStyle(fontSize: 20)),
              Text("部首：${widget.data.radical}",
                  style: TextStyle(fontSize: 20)),
              Text("筆畫數：${widget.data.strokes}",
                  style: TextStyle(fontSize: 20)),
              Text("同音字：${widget.data.polyphone}",
                  style: TextStyle(fontSize: 20)),
              SizedBox(height: 8),
              Text(
                "字義：${widget.data.meaning}",
                style: GoogleFonts.notoSansTc(
                  fontSize: 22,
                  height: 1.5,
                  color: Colors.black87,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.notoSansTc(
            fontSize: 18,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: "$label：",
              style: GoogleFonts.notoSansTc(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
                fontSize: 18,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
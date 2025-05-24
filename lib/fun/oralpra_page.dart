
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class WordCardData {
  final String word;
  final String id;
  final String pinyin;
  final String zhuyin;
  final String radical;
  final String strokes;
  final String meaning;
  final String polyphone;

  @override
  String toString() {
    return 'WordCardData(word: $word, id: $id, pinyin: $pinyin, zhuyin: $zhuyin, radical: $radical, strokes: $strokes, meaning: $meaning, polyphone: $polyphone)';
  }

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
      radical: json["radical"]?.trim().isEmpty ?? true ? "無" : json["radical"],
      strokes: json["strokes"] ?? "0",
      meaning: (json["meaning"] ?? "無").replaceAll("\n", " "),
      // 將換行符號替換為空格
      polyphone: json["polyphone"] ?? "無",
    );
  }
}


  class FlashcardScreen1 extends StatefulWidget {
    const FlashcardScreen1({Key? key}) : super(key: key);

    @override
    State<FlashcardScreen1> createState() => _FlashcardScreenState();
  }

class _FlashcardScreenState extends State<FlashcardScreen1> {
  List<WordCardData> _cards = [];
  List<WordCardData> _filteredCards = [];
  int _currentIndex = 0;
  TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    loadJsonData();
  }

  Future<void> loadJsonData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/words.json');
      List<dynamic> jsonList = jsonDecode(jsonString);
      List<WordCardData> loadedCards =
      jsonList.map((json) => WordCardData.fromJson(json)).toList();


      setState(() {
        _cards = loadedCards;
        _filteredCards = loadedCards;
      });
    } catch (e) {
      print("讀取 JSON 發生錯誤: $e");
    }
  }
  // 根據傳遞過來的字詞過濾字卡資料


  // 搜尋字卡
  void filterCards(String query) {
    setState(() {
      _filteredCards = _cards.where((card) {
        final q = query.trim();
        return card.word.contains(q) ||
            card.zhuyin.contains(q) ||
            card.pinyin.toLowerCase().contains(q.toLowerCase()) ||
            card.radical.contains(q);
      }).toList();
      _currentIndex = 0; // 每次搜尋時重置至第一張
    });
  }

  // 顯示下一張字卡
  void nextCard() {
    if (_filteredCards.isEmpty) return;  // ⬅️ 防止沒資料時亂跳
    setState(() {
      final random = Random();
      int newIndex;
      do {
        newIndex = random.nextInt(_filteredCards.length);
      } while (newIndex == _currentIndex && _filteredCards.length > 1);
      _currentIndex = newIndex;
    });
  }


  Widget build(BuildContext context) {
    print("字卡資料數量: ${_cards.length}");
    final currentCard = _filteredCards.isNotEmpty
        ? _filteredCards[_currentIndex]
        : null;

  return Scaffold(
        body: Column(
        children: [
        Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
        hintText: '搜尋',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
        ? IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
        setState(() {
        _searchController.clear();
        query = '';
        filterCards(''); // 重設搜尋結果
        });
        },
    )
        : null,
    ),
    onChanged: (value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
    setState(() {
    query = value.trim();
    if (query.isNotEmpty && !searchHistory.contains(query)) {
    searchHistory.insert(0, query);
    if (searchHistory.length > 5) searchHistory.removeLast();
    }
    filterCards(query);  // 搜尋字卡
    });
    });
    },
    ),
    ),
    // 其他元件...
          if (searchHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "搜尋紀錄：${searchHistory.join(', ')}",
                  style: TextStyle(fontSize: 20,color: Colors.grey[700]),
    ),
    ),
    ),
          Expanded(
            child: Center(
              child: currentCard == null
                  ? Text(
                '沒有找到符合的字卡',
                style: TextStyle(fontSize: 30, color: Colors.grey),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FlipCard(data: currentCard),  // 顯示翻轉字卡
                  SizedBox(height: 30),
                  if (query.isEmpty)
                  ElevatedButton(
                    onPressed: nextCard,
                    child: Text('下一頁',style: TextStyle(fontSize: 30,color: Color(0xFF124E78))),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 字卡資料


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
        layoutBuilder: (currentChild, previousChildren) => Stack(
          children: [if (currentChild != null) currentChild, ...previousChildren],
        ),
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
        height: 350,
        decoration: BoxDecoration(
          color: Color(0xFF90DBF4),//總複習字卡顏色
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            widget.data.word,
            style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold,color: Color(0xFF124E78)),
          ),
        ),
      );

  Widget _buildBack() {
    print(widget.data.toString());
    return Container(
      key: ValueKey(false),
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        color:Colors.amber.shade100,
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
                    fontSize: 20,
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
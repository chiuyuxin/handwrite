
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:app1/fun/challenge_menu_page.dart';
import 'package:app1/fun/card_page.dart';
import 'package:app1/fun/oralpra_page.dart';
import 'package:app1/fun/profile_page.dart';
import 'package:provider/provider.dart';             // 匯入 Provider 套件
import 'package:app1/fun/word_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';// 匯入你自訂的 WordProvider


class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.red.shade100,
          secondary: Colors.purple.shade100,
        ),
        useMaterial3: true,
      ),
      home: HomePage1(),
    );
  }
}



class HomePage1 extends StatefulWidget {
  @override
  State<HomePage1> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage1> {
  int _selectedIndex = 0;
  List<String> savedCharacters = [];
  bool showPinyin = false;
  List<String> searchHistory = [];
  String query = '';



  @override
  void initState() {
    super.initState();
    Provider.of<WordProvider>(context, listen: false).initializeWords();
    _loadSavedCharacters();
  }


  void _loadSavedCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;


    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();

          final cloudSaved = List<String>.from(data?['savedCharacters'] ?? []);
          setState(() {
            savedCharacters = cloudSaved;
          });
          await prefs.setStringList('saved_${user.uid}', cloudSaved); // 存一份到本地快取
          return;
        }
      } catch (e) {
        print('從 Firebase 載入失敗，改用本地: $e');
      }
    }
    final localKey = user != null ? 'saved_${user.uid}' : 'saved_guest';
    setState(() {
      savedCharacters = prefs.getStringList(localKey) ?? [];
    });


  }

  void _toggleSave(String char) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final key = user != null ? 'saved_${user.uid}' : 'saved_guest';



    setState(() {
      if (savedCharacters.contains(char)) {
        savedCharacters.remove(char);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已從收藏移除：$char")));
      } else {
        savedCharacters.add(char);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已加入收藏：$char")));
      }
    });

    // 本地存一份
    await prefs.setStringList(key, savedCharacters);

    // 如果有登入，更新到 Firebase
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'savedCharacters': savedCharacters,
        }, SetOptions(merge: true));
      } catch (e) {
        print('同步到 Firebase 失敗: $e');
      }
    }
  }





  void logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('guest_') || key.startsWith('${user?.uid ?? 'guest'}_')) {
        await prefs.remove(key);
      }
    }


    // 清除 guest 收藏
    await prefs.remove('saved_guest');

    await FirebaseAuth.instance.signOut(); // 確保也登出 Firebase
    await prefs.remove('isGuest');
    await prefs.remove('account');

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (Route<dynamic> route) => false,
    );
  }





  @override
  Widget build(BuildContext context) {
    final allCharacters = Provider.of<WordProvider>(context).words;

    if (allCharacters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("生字對對對")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final filteredCharacters = allCharacters
        .where((char) => char['word']!.contains(query))
        .toList();

    Widget currentScreen;
    switch (_selectedIndex) {
      case 1:
        final saved = allCharacters
            .where((char) => savedCharacters.contains(char['word']))
            .toList();
        currentScreen = buildGridView(saved);
        break;
      case 2:
        currentScreen = FlashcardScreen1();
        break;
      case 3:
        currentScreen = StatsPage(allCharacters: allCharacters);
        break;
      case 4:
        currentScreen = ChallengeMenuPage();
        break;


      default:
        currentScreen = Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: '搜尋',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  query = value.trim();
                  if (query.isNotEmpty && !searchHistory.contains(query)) {
                    searchHistory.insert(0, query);
                    if (searchHistory.length > 5) searchHistory.removeLast();
                  }
                });
              },
            ),
            if (searchHistory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("搜尋紀錄：${searchHistory.join(', ')}",
                      style: TextStyle(color: Colors.grey[700])),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("顯示：", style: TextStyle(fontSize: 25,color: Color(0xFF124E78))),
                Switch(
                  value: showPinyin,
                  onChanged: (val) => setState(() => showPinyin = val),
                  activeColor: Color(0xFF124E78),
                  activeTrackColor: Colors.amber,
                  inactiveThumbColor: Color(0xFF124E78),

                ),
                Text(showPinyin ? " 拼音" : " 注音",
                    style: TextStyle(fontSize: 25,color: Color(0xFF124E78))),

              ],
            ),
            Expanded(child: buildGridView(filteredCharacters)),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF124E78),
        title: Text(
            "生字對對對",
            style: TextStyle(fontSize: 30,color: Colors.white,)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.logout,color: Colors.white),
          onPressed: () => logout(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person,color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: currentScreen,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF124E78),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),

        selectedIconTheme: IconThemeData(size: 40),      // 選中 icon 大小
        unselectedIconTheme: IconThemeData(size: 32),    // 未選中 icon 大小
        selectedLabelStyle: TextStyle(fontSize: 30),     // 選中文字大小
        unselectedLabelStyle: TextStyle(fontSize: 20),   // 未選中文字大小

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "首頁"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "生字收藏簿"),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "總複習"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "學習紀錄"),
          BottomNavigationBarItem(icon: Icon(Icons.videogame_asset), label: "挑戰模式"),
        ],
      ),
    );
  }

    Widget buildGridView(List<Map<String, String>> characters) {
    if (characters.isEmpty) {
      return Center(
        child: Text('沒有資料', style: TextStyle(fontSize: 20, color: Colors.grey)),
      );
    }

    return GridView.builder(

      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final char = characters[index];
        final character = char['word']!;
        final id = char['id']!;
        final isSaved = savedCharacters.contains(character);
        final pronunciation = showPinyin ? char['pinyin']! : char['zhuyin']!;

        return InkWell(
          onTap: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HandwritingPage(
                  character: character,
                  strokeId: id,
                  initiallySaved: isSaved,
                ),
              ),
            );
            if (updated != null && updated is bool && updated != isSaved) {
              _toggleSave(character);
            }
          },

          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            color: Color(0xFF90DBF4),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(character,
                          style: TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF124E78))),
                      SizedBox(height: 8),
                      Text(pronunciation,
                          style: TextStyle(fontSize: 35, color: Color(0xFF124E78))),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _toggleSave(character),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isSaved ? Icons.star : Icons.star_border,
                        key: ValueKey(isSaved),
                        color: isSaved ? Colors.amber : Color(0xFF124E78),
                          size: 40
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class HandwritingPage extends StatefulWidget {
  final String character;
  final String strokeId;
  final bool initiallySaved;

  HandwritingPage({
    required this.character,
    required this.strokeId,
    required this.initiallySaved,
  });

  @override
  _HandwritingPageState createState() => _HandwritingPageState();
}

class _HandwritingPageState extends State<HandwritingPage>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  int correctCount = 0;
  int incorrectCount = 0;
  bool isSaved = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    isSaved = widget.initiallySaved;
    _loadStats();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
      lowerBound: 0.8,
      upperBound: 1.2,
    );

    _scaleAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
  }

  void _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "guest";

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final firebaseRecord = doc.data()?['records']?[widget.character];
          if (firebaseRecord != null) {
            setState(() {
              correctCount = firebaseRecord['correct'] ?? 0;
              incorrectCount = firebaseRecord['incorrect'] ?? 0;
            });
            return;
          }
        }
      } catch (e) {
        print("從 Firebase 載入學習紀錄失敗：$e");
      }
      // Firebase 無資料 → 初始化為 0
      setState(() {
        correctCount = 0;
        incorrectCount = 0;
      });
    } else {
      // 訪客 → 使用本地紀錄
      setState(() {
        correctCount = prefs.getInt('${uid}_${widget.character}_correct') ?? 0;
        incorrectCount = prefs.getInt('${uid}_${widget.character}_incorrect') ?? 0;
      });
    }
  }


  void _incrementStat(bool correct) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? "guest";

    if (correct) {
      setState(() {
        correctCount++;
      });
      await prefs.setInt('${uid}_${widget.character}_correct', correctCount);
    } else {
      setState(() {
        incorrectCount++;
      });
      await prefs.setInt('${uid}_${widget.character}_incorrect', incorrectCount);
    }


    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);


        final snapshot = await docRef.get();
        Map<String, dynamic> records = snapshot.data()?['records'] ?? {};


        records[widget.character] = {
          'correct': correctCount,
          'incorrect': incorrectCount,
        };

        await docRef.set({
          'records': {
            widget.character: {
              'correct': correctCount,
              'incorrect': incorrectCount,
            }
          }
        }, SetOptions(merge: true));

      } catch (e) {
        print("儲存書寫記錄到Firebase失敗: $e");
      }
    }
  }

  void _toggleSaveAndAnimate() {
    setState(() {
      isSaved = !isSaved;
    });

    _animationController.forward().then((_) => _animationController.reverse());
    Navigator.pop(context, isSaved); // 只回傳收藏結果
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("書寫: ${widget.character}"),
        actions: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: Icon(
                isSaved ? Icons.star : Icons.star_border,
                color: isSaved ? Colors.amber : Colors.white,
              ),
              onPressed: _toggleSaveAndAnimate,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialFile: "assets/hanzi_writer.html",
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              controller.addJavaScriptHandler(
                handlerName: "onResult",
                callback: (args) {
                  String result = args[0];
                  bool correct = result == "correct";
                  _incrementStat(correct);
                  _showMessage(correct ? "筆順正確 ✅" : "筆順錯誤 ❌");
                },
              );
            },
            onLoadStop: (controller, url) {
              _webViewController!
                  .evaluateJavascript(source: "loadCharacter('${widget.character}');");
            },
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                Chip(
                  label: Text('✅ $correctCount'),
                  backgroundColor: Colors.green.shade100,
                ),
                SizedBox(height: 6),
                Chip(
                  label: Text('❌ $incorrectCount'),
                  backgroundColor: Colors.red.shade100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    final overlay = OverlayEntry(
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    Future.delayed(Duration(seconds: 2), () => overlay.remove());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}



import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app1/fun/word_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ChallengeGamePage extends StatefulWidget {
  final List<Map<String, String>> allCharacters;

  final Function(int) onGameEnd;

  const ChallengeGamePage({
    super.key,
    required this.allCharacters,
    required this.onGameEnd,
  });


  @override
  _ChallengeGamePageState createState() => _ChallengeGamePageState();
}

class _ChallengeGamePageState extends State<ChallengeGamePage> {
  InAppWebViewController? _webViewController;
  Timer? _timer;
  int _remainingTime = 60;
  int _score = 0;
  bool _isRunning = false;
  bool _webViewReady = false;
  String _currentChar = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _nextCharacter();
    _isRunning = true;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime == 0) {
        _endGame();
      } else {
        setState(() {
          _remainingTime--;
        });
      }
    });
  }

  void _nextCharacter() {
    final random = widget.allCharacters[Random().nextInt(widget.allCharacters.length)];
    setState(() {
      _currentChar = random['word']!;
    });

    if (_webViewReady) {
      _webViewController?.evaluateJavascript(
        source: "loadCharacter('$_currentChar');",
      );
    }
  }

  void _onResult(String result) {
    if (!_isRunning) return;
    if (result == "correct") {
      setState(() {
        _score+=5;
      });
      _nextCharacter();
    }
  }

  Future<void> _endGame() async {
    _timer?.cancel();
    _isRunning = false;

    // ✅ 通知主頁處理儲存
    widget.onGameEnd(_score);

    // ✅ 顯示對話框（只顯示當前遊戲得分，不顯示總積分）
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("時間到！"),
        content: Text("你的分數: $_score "),
        actions: [
          TextButton(
            child: Text("再玩一次"),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _remainingTime = 60;
                _score = 0;
              });
              _startGame();
            },
          ),
          TextButton(
            child: Text("回首頁"),
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allCharacters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("60秒挑戰")),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('60秒挑戰')),
      body: Stack(
        children: [
          InAppWebView(
            initialFile: "assets/challenge_writer.html",
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _webViewReady = true;
              controller.addJavaScriptHandler(
                handlerName: "onResult",
                callback: (args) {
                  _onResult(args[0]);
                },
              );
            },
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("剩餘時間：$_remainingTime 秒", style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text("得分：$_score", style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: ElevatedButton(
              onPressed: () {
                if (!_isRunning && _webViewReady) {
                  setState(() {
                    _remainingTime = 60;
                    _score = 0;
                  });
                  _startGame();
                }
              },
              child: Text("開始遊戲"),
            ),
          ),
        ],
      ),
    );
  }
}




class ChallengeCatchGamePage extends StatefulWidget {
  final Function(int) onGameEnd;

  const ChallengeCatchGamePage({
    super.key,
    required this.onGameEnd,
  });

  @override
  _ChallengeCatchGamePageState createState() => _ChallengeCatchGamePageState();
}

class _ChallengeCatchGamePageState extends State<ChallengeCatchGamePage> with SingleTickerProviderStateMixin {
  double basketX = 0.5;
  late Timer gameTimer;
  int remainingTime = 60;
  int score = 0;
  List<_FallingCharacter> fallingCharacters = [];
  late AnimationController _fallController;
  Random random = Random();
  Map<String, String> currentTarget = {};
  bool hasCorrectChar = false;

  bool gameStarted = false;
  bool countdownStarted = false;
  int countdown = 3;
  bool flashCorrect = false; // 正確接到動畫

  @override
  void initState() {
  super.initState();
  _fallController =
  AnimationController(vsync: this, duration: Duration(milliseconds: 16))
  ..addListener(_updateFall)
  ..repeat();
  }

  void _startCountdownAndGame() {
  setState(() {
  countdownStarted = true;
  countdown = 3;
  });

  Timer.periodic(Duration(seconds: 1), (timer) {
  setState(() {
  countdown--;
  });

  if (countdown == 0) {
  timer.cancel();
  setState(() {
  countdownStarted = false;
  gameStarted = true;
  });
  _startGame();
  }
  });
  }

  void _startGame() {
  _generateNewTarget();
  _spawnCharacter();
  remainingTime = 60;
  score = 0;
  gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  setState(() {
  remainingTime--;
  });
  if (remainingTime <= 0) {
  _endGame();
  }
  });
  }

  void _generateNewTarget() {
  final allCharacters = Provider
      .of<WordProvider>(context, listen: false)
      .words;
  if (allCharacters.isEmpty) return;
  final target = allCharacters[random.nextInt(allCharacters.length)];
  setState(() {
  currentTarget = {
  'zhuyin': target['zhuyin']!,
  };
  hasCorrectChar = false;
  });
  }

  void _spawnCharacter() {
  final allCharacters = Provider
      .of<WordProvider>(context, listen: false)
      .words;
  Timer.periodic(Duration(milliseconds: 1200), (timer) {
  if (!gameStarted || remainingTime <= 0) {
  timer.cancel();
  return;
  }
  if (allCharacters.isEmpty) return;

  bool spawnCorrect = !hasCorrectChar && random.nextDouble() < 0.5;
  final char = spawnCorrect
  ? allCharacters.firstWhere((c) =>
  c['zhuyin'] == currentTarget['zhuyin'],
  orElse: () => allCharacters[random.nextInt(allCharacters.length)])
      : allCharacters[random.nextInt(allCharacters.length)];

  setState(() {
  fallingCharacters.add(
  _FallingCharacter(
  word: char['word']!,
  zhuyin: char['zhuyin']!,
  positionX: random.nextDouble() * 0.8,
  positionY: 0,
  ),
  );
  if (char['zhuyin'] == currentTarget['zhuyin']) {
  hasCorrectChar = true;
  }
  });
  });
  }

  void _updateFall() {
  setState(() {
  for (var fc in fallingCharacters) {
  fc.positionY += 6;
  }
  _checkCollision();

  // 🔥 如果錯過了正確答案（沒接到就消失）
  bool missedCorrect = fallingCharacters.any((fc) =>
  fc.zhuyin == currentTarget['zhuyin'] &&
  fc.positionY > MediaQuery.of(context).size.height);
  if (missedCorrect) {
  _generateNewTarget();
  }

  // 清除畫面外的字
  fallingCharacters.removeWhere((fc) =>
  fc.positionY > MediaQuery.of(context).size.height);
  });
  }


  void _checkCollision() {
  double basketLeft = basketX * MediaQuery
      .of(context)
      .size
      .width;
  double basketRight = basketLeft + 100;
  double basketTop = MediaQuery
      .of(context)
      .size
      .height - 80;

  List<_FallingCharacter> caughtChars = [];

  for (var fc in fallingCharacters) {
  double charX = fc.positionX * MediaQuery
      .of(context)
      .size
      .width;
  if (fc.positionY >= basketTop && charX > basketLeft - 30 &&
  charX < basketRight + 30) {
  if (fc.zhuyin == currentTarget['zhuyin']) {
  score += 10;
  flashCorrect = true; // 🔥 正確閃爍
  Future.delayed(Duration(milliseconds: 300), () {
  setState(() => flashCorrect = false);
  });
  _generateNewTarget();
  } else {
  remainingTime -= 5;
  if (remainingTime < 0) remainingTime = 0;
  }
  caughtChars.add(fc);
  }
  }

  setState(() {
  fallingCharacters.removeWhere((fc) => caughtChars.contains(fc));
  });
  }

  void _endGame() {
    _fallController.stop();
    gameTimer.cancel();
    widget.onGameEnd(score);  // ✅ 通知主頁處理儲存
    setState(() {
      gameStarted = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("遊戲結束"),
        content: Text("你的得分：$score 分"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                fallingCharacters.clear();
                _startCountdownAndGame();
              });
            },
            child: Text("再來一次"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("退出遊戲"),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _fallController.dispose();
    if (gameTimer.isActive) gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final allCharacters = Provider.of<WordProvider>(context).words;

    if (allCharacters.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("接蘋果")),
        body: Center(child: CircularProgressIndicator()),
      );
    }


    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            basketX += details.delta.dx / MediaQuery.of(context).size.width;
            basketX = basketX.clamp(0.0, 0.8);
          });
        },
        child: Stack(
          children: [
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),

            if (!gameStarted && !countdownStarted)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    _startCountdownAndGame();
                  },
                  child: Text("開始挑戰", style: TextStyle(fontSize: 24)),
                ),

              ),
            if (countdownStarted)
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 1.0, end: 1.4),
                  duration: Duration(milliseconds: 500),
                  builder: (context, double scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Text(
                        countdown > 0 ? '$countdown' : 'GO!',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink.shade400,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black26,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            // 中央注音
            if (gameStarted)
              Center(
                child: AnimatedOpacity(
                  opacity: flashCorrect ? 0.0 : 1.0,
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    currentTarget['zhuyin'] ?? '',
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontFamily: 'RoundedMplus',
                      shadows: [
                        Shadow(blurRadius: 6, color: Colors.black26, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                ),
              ),
            // 生字
            ...fallingCharacters.map((fc) => Positioned(
              top: fc.positionY.toDouble(),
              left: fc.positionX * MediaQuery.of(context).size.width,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.redAccent.shade100,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  fc.word,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )),
            // 分數與時間
            Positioned(
              top: 40,
              left: 70,
              child: Text("時間：$remainingTime", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Text("得分：$score", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            // 籃子
            Positioned(
              bottom: 30,
              left: basketX * MediaQuery.of(context).size.width,
              child: Icon(
                Icons.shopping_basket,
                size: 100,
                color: Colors.brown.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WhacAMolePage extends StatefulWidget {
  final Function(int) onGameEnd;

  const WhacAMolePage({super.key, required this.onGameEnd});

  @override
  State<WhacAMolePage> createState() => _WhacAMolePageState();
}

class _WhacAMolePageState extends State<WhacAMolePage> {
  List<Map<String, dynamic>> words = [];
  String targetRadical = '';
  List<int?> activeMoles = [null, null, null];
  int score = 0;
  int timeLeft = 60;
  Timer? gameTimer;
  Timer? moleTimer;
  Timer? radicalTimer;
  Timer? ensureCorrectTimer;
  Timer? countdownTimer; //
  Random random = Random();
  bool gameStarted = false;
  bool countdownStarted = false;
  int countdown = 3;


  bool correctWordAppeared = false; // 追蹤是否出現過正確的字

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WordProvider>(context, listen: false);
      setState(() {
        words = provider.words.map((w) =>
        {
          'word': w['word'],
          'radical': w['radical'],
        }).toList();
      });

    });
  }


  @override
  void dispose() {
    gameTimer?.cancel();
    moleTimer?.cancel();
    radicalTimer?.cancel();
    ensureCorrectTimer?.cancel();
    super.dispose();
  }


  void _startMoleGame() {
    score = 0;
    timeLeft = 60;
    activeMoles = [null, null, null];
    targetRadical = (words..shuffle()).first['radical'].trim();
    correctWordAppeared = false;
    gameStarted = true;


    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
      });
      if (timeLeft <= 0) {
        timer.cancel();
        moleTimer?.cancel();
        radicalTimer?.cancel();
        ensureCorrectTimer?.cancel();
        showEndDialog();
      }
    });

    moleTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {

      if (words.isEmpty) return;
      int holeIndex = random.nextInt(3);
      if (activeMoles[holeIndex] != null) return;

      // 隨機選一個字
      Map<String, dynamic> selectedWord = words[random.nextInt(words.length)];

      setState(() {
        activeMoles[holeIndex] = words.indexOf(selectedWord);

        // 如果這個字的部首是對的，就標記 correctWordAppeared
        if (selectedWord['radical'].trim() == targetRadical) {
          correctWordAppeared = true;
        }
      });

      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            activeMoles[holeIndex] = null;
          });
        }
      });
    });

    radicalTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (words.isEmpty) return;
      setState(() {
        targetRadical = (words..shuffle()).first['radical'].trim();
      });
    });

    ensureCorrectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!correctWordAppeared) {
        // 沒有出現過正確的字，就強制生成一隻正確的小貓
        int availableHole = activeMoles.indexWhere((element) =>
        element == null);
        if (availableHole != -1) {
          // 找一個空的洞
          List<Map<String, dynamic>> correctWords = words
              .where((word) => word['radical'].trim() == targetRadical)
              .toList();
          if (correctWords.isNotEmpty) {
            Map<String, dynamic> correctWord = correctWords[random.nextInt(
                correctWords.length)];
            setState(() {
              activeMoles[availableHole] = words.indexOf(correctWord);
              correctWordAppeared = true;
            });
            Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  activeMoles[availableHole] = null;
                });
              }
            });
          }
        }
      }
      correctWordAppeared = false; // 重置下一輪
    });
  }

  void showEndDialog() {
    gameStarted = false;

    widget.onGameEnd(score);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Text('遊戲結束'),
            content: Text('你的得分：$score'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startMoleGame();
                },
                child: const Text('再玩一次'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                    ..pop()..pop();
                },
                child: const Text('返回'),
              ),
            ],
          ),
    );
  }
  void _startCountdownAndGame() {
    setState(() {
      countdownStarted = true;
      countdown = 3;
    });

    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
      });

      if (countdown == 0) {
        timer.cancel();
        setState(() {
          gameStarted = true;
          countdownStarted = false;
        });
        _startMoleGame();
      }
    });
  }

  void handleTap(int holeIndex) {
    if (activeMoles[holeIndex] == null) return;

    final wordData = words[activeMoles[holeIndex]!];
    final String wordRadical = wordData['radical'].trim();

    setState(() {
      if (wordRadical == targetRadical) {
        score += 5;
      } else {
        timeLeft -= 5;
        if (timeLeft < 0) timeLeft = 0;
      }
      activeMoles[holeIndex] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("打地鼠 - 找部首的小貓")),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('打地鼠 - 找部首的小貓')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text('目標部首：$targetRadical', style: const TextStyle(fontSize: 28)),
          Text('得分：$score', style: const TextStyle(fontSize: 24)),
          Text('剩餘時間：$timeLeft秒', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 10),
          // 👇 中央按鈕或倒數動畫
          if (!gameStarted && !countdownStarted)
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _startCountdownAndGame();
                },
                child: const Text("開始挑戰", style: TextStyle(fontSize: 24)),
              ),
            ),
          if (countdownStarted)
            Center(
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 1.0, end: 1.4),
                duration: const Duration(milliseconds: 500),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Text(
                      countdown > 0 ? '$countdown' : 'GO!',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlue.shade400,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black26,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // 👇 遊戲主畫面：貓/洞 + 文字
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                final moleIndex = activeMoles[index];
                return GestureDetector(
                  onTap: () => handleTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: moleIndex != null
                            ? Image.asset('assets/cat.png', fit: BoxFit.contain)
                            : Image.asset(
                            'assets/hole.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      moleIndex != null
                          ? Text(
                        words[moleIndex]['word'],
                        style: const TextStyle(fontSize: 40),
                      )
                          : const SizedBox.shrink(),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

  class _FallingCharacter {
  String word;
  String zhuyin;
  double positionX;
  double positionY;

  _FallingCharacter({
    required this.word,
    required this.zhuyin,
    required this.positionX,
    required this.positionY,
  });
}

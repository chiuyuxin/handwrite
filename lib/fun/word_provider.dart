// lib/fun/word_provider.dart
import 'package:flutter/material.dart';
import 'word_data_provider.dart';

class WordProvider extends ChangeNotifier {
  List<Map<String, String>> _words = [];

  List<Map<String, String>> get words => _words;

  Future<void> initializeWords() async {
    _words = await WordDataProvider().getWords();
    notifyListeners();
  }

  // 可擴充：搜尋功能
  List<Map<String, String>> search(String keyword) {
    return _words.where((word) => word['word']!.contains(keyword)).toList();
  }
}

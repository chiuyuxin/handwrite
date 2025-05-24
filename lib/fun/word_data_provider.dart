import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class WordDataProvider {
  static final WordDataProvider _instance = WordDataProvider._internal();
  factory WordDataProvider() => _instance;
  WordDataProvider._internal();

  Future<List<Map<String, String>>>? _cachedData;

  Future<List<Map<String, String>>> getWords() {
    if (_cachedData != null) {
      return _cachedData!;
    }
    _cachedData = _loadData();
    return _cachedData!;
  }

  Future<List<Map<String, String>>> _loadData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/words.json');
      List<dynamic> jsonList = jsonDecode(jsonString);

      return jsonList.map<Map<String, String>>((json) {
        String radical = json["radical"] ?? "";
        radical = radical.trim().isEmpty ? "無" : radical;

        return {
          'word': json["word"] ?? " ",
          'id': json["id"] ?? " ",
          'pinyin': json["pinyin"] ?? " ",
          'zhuyin': json["zhuyin"] ?? " ",
          'radical': radical,
          'strokes': json["strokes"] ?? "0",
          'meaning': (json["meaning"] ?? "無").replaceAll("\n", " "),
          'polyphone': json["polyphone"] ?? "無",
        };
      }).toList();
    } catch (e) {
      print("讀取錯誤: $e");
      return [];
    }
  }
}

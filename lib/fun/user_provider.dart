import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _uid = '';
  String _username = '';

  String get uid => _uid;
  String get username => _username;

  void setUid(String uid) {
    _uid = uid;
    notifyListeners();
  }

  void setUsername(String username) {
    _username = username;
    notifyListeners();
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum StorageKeys {
  USER('USER_KEY');

  final String value;
  const StorageKeys(this.value);
}

class StorageService {
  late SharedPreferences sharedPreference;
  StorageService._();

  static final instance = StorageService._();

  Future<void> initStorage() async {
    sharedPreference = await SharedPreferences.getInstance();
  }

  Future<void> save(StorageKeys storageKeys, Map<String, dynamic> data) async {
    // return {sharedPreference.setString(key, value)};
    sharedPreference.setString(storageKeys.value, jsonEncode(data));
  }

  Map<String, dynamic> get(StorageKeys storageKeys) {
    final data = sharedPreference.getString(storageKeys.value);
    if (data == null) {
      return {};
    }
    return jsonDecode(data);
  }
}

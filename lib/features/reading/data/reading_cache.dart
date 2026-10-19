import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/feed_exception.dart';
import '../domain/reading_feed.dart';
import 'feed_json.dart';

abstract interface class ReadingCache {
  Future<List<ReadingFeed>> load();
  Future<void> save(List<ReadingFeed> feeds);
}

class SharedPreferencesReadingCache implements ReadingCache {
  SharedPreferencesReadingCache({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const storageKey = 'folio.feeds.v1';
  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<List<ReadingFeed>> load() async {
    final saved = (await _preferences()).getString(storageKey);
    if (saved == null) return const [];
    return List.unmodifiable(
      (jsonDecode(saved) as List).map(
        (feed) => feedFromJson(Map<String, dynamic>.from(feed as Map)),
      ),
    );
  }

  @override
  Future<void> save(List<ReadingFeed> feeds) async {
    final preferences = await _preferences();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(feeds.map(feedToJson).toList()),
    );
    if (!saved) {
      throw const FeedException(
        'Your feeds couldn’t be saved on this device. Please try again.',
      );
    }
  }
}

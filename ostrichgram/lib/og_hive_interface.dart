import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_macos/path_provider_macos.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';
import 'dart:io';
import 'dart:convert';

/*

  This class is a collection of static functions for DB operations.  The app creates a folder
  in myDocuments called OstrichGram_DB.hive.  Hive is an embedded DB and each "box" is essentially a table.
  We have the following boxes:

  aliases.hive - holds user IDs
  chosen_alias.hive - holds the current active ID
  config_settings.hive - holds configuration settings
  friends.hive - holds contacts (friends) info , keyed by pubkey
  groups.hive - holds groups. Each group key is a tuple of the group id and relay
  messages_friend.hive - holds DMs.  Each key is a composite key of the concatenation of alias pubkey and friend pubkey, along with the unique message id
  messages_group.hive - holds group messages. Each key is a composite of the group id and a unique message id
  messages_relay.hive - holds list of chatrooms for each relay
  relays.hive - holds list of relays
  messages_group_cache_watermark.hive - holds list of group IDs and the most recent created_at timestamp that we fetched.
  messages_fat_group_cache_watermark.hive - holds list of group IDs and the most recent created_at timestamp that we fetched.  Group id can be the id , underscore, relay.
  messages_fatgroup.hive -- messages for fatgroups
  fatgroups.hive - holds fat groups (a fat group is a multi relay chat).

   */



class OG_HiveInterface {
  static  Box? _friends_box;
  static  Box?  _alias_box;
  static  Box?  _relays_box;
  static  Box? _groups_box;
  static  Box? _fat_groups_box;
  static  Box? _chosen_alias_box;
  static  Box? _messages_relay_box;
  static  Box? _messages_group_box;
  static  Box? _messages_fat_group_box;
  static  Box? _messages_friend_box;
  static  Box? _config_settings_box;
  static  Box? _messages_group_cache_watermark_box;
  static  Box? _messages_fat_group_cache_watermark_box;
  static late Directory appDocumentDir;
  static late String hiveDbPath;
  static final _lock = Lock();
  static bool _isInitialized = false;

  OG_HiveInterface() {
    init();
  }

  static Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    await Hive.initFlutter();

     appDocumentDir = await getApplicationDocumentsDirectory();
      hiveDbPath = "${appDocumentDir.path}/OstrichGram_DB.hive";
    if (!await appDocumentDir.exists()) {
      await appDocumentDir.create();
    }
    _friends_box = await Hive.openBox('friends',path: hiveDbPath);
    _alias_box = await Hive.openBox('aliases', path: hiveDbPath);
    _relays_box = await Hive.openBox('relays', path: hiveDbPath);

    _chosen_alias_box = await Hive.openBox('chosen_alias', path: hiveDbPath);
    _groups_box = await Hive.openBox('groups', path: hiveDbPath);
    _fat_groups_box = await Hive.openBox('fat_groups', path: hiveDbPath);

    _messages_group_box = await Hive.openBox('messages_group', path: hiveDbPath);

    _messages_fat_group_box = await Hive.openBox('messages_fat_group', path: hiveDbPath);
    _messages_friend_box = await Hive.openBox('messages_friend', path: hiveDbPath);
    _config_settings_box = await Hive.openBox('config_settings', path: hiveDbPath);
    _messages_group_cache_watermark_box = await Hive.openBox('messages_group_cache_watermark', path: hiveDbPath);
    _messages_fat_group_cache_watermark_box = await Hive.openBox('messages_fat_group_cache_watermark', path: hiveDbPath);

    _isInitialized = true;
  }

static String getHiveDbPath() {
    return hiveDbPath;
}
  static Future<void> initRelaysBox() async {
    if (_relays_box == null || !(_relays_box?.isOpen ?? false)) {
      _relays_box = await Hive.openBox('relays', path: hiveDbPath);
    }
  }


  static Future<void> initGroupsBox() async {
    if (_groups_box == null || !(_groups_box?.isOpen ?? false)) {
      _groups_box = await Hive.openBox('groups', path: hiveDbPath);
    }
  }


  static Future<void> initFatGroupsBox() async {
    if (_fat_groups_box == null || !(_fat_groups_box?.isOpen ?? false)) {
      _fat_groups_box = await Hive.openBox('fat_groups', path: hiveDbPath);
    }
  }


  static Future<void> initFriendsBox() async {
    if (_friends_box == null || !(_friends_box?.isOpen ?? false)) {
      _friends_box = await Hive.openBox('friends', path: hiveDbPath);
    }
  }

  static Future<void> initMessagesRelaysBox() async {
    if (_messages_relay_box == null || !(_messages_relay_box?.isOpen ?? false)) {
      _messages_relay_box = await Hive.openBox('messages_relay', path: hiveDbPath);
    }
  }


  static Future<void> initMessagesGroupsBox() async {
    if (_messages_group_box == null || !(_messages_group_box?.isOpen ?? false)) {
      _messages_group_box = await Hive.openBox('messages_group', path: hiveDbPath);
    }
  }


  static Future<void> initMessagesFriendsBox() async {
    if (_messages_friend_box == null || !(_messages_friend_box?.isOpen ?? false)) {
      _messages_friend_box = await Hive.openBox('messages_friend', path: hiveDbPath);
    }
  }


  static Future<Map<String, dynamic>> getData_GroupCacheWatermark(String group_id) async {
    if (group_id.isEmpty) {
      throw Exception('Group ID cannot be blank.');
    }
    Box box;
    if (OG_HiveInterface._messages_group_cache_watermark_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_group_cache_watermark_box ??
          await Hive.openBox('messages_group_cache_watermark');
    } else {
      box = await Hive.openBox('messages_group_cache_watermark', path: hiveDbPath);
    }

    final groupMap = box.get(group_id, defaultValue: null);
    if (groupMap is Map) {
      return groupMap.cast<String, dynamic>();
    } else {
      return <String, dynamic>{};  // Return an empty map if groupMap is not a Map.
    }
  }

  static Future<Map<String, dynamic>> getData_FatGroupCacheWatermark(String group_id) async {
    if (group_id.isEmpty) {
      throw Exception('Group ID cannot be blank.');
    }
    Box box;
    if (OG_HiveInterface._messages_fat_group_cache_watermark_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_fat_group_cache_watermark_box ??
          await Hive.openBox('messages_fat_group_cache_watermark');
    } else {
      box = await Hive.openBox('messages_fat_group_cache_watermark', path: hiveDbPath);
    }

    final groupMap = box.get(group_id, defaultValue: null);
    if (groupMap is Map) {
      return groupMap.cast<String, dynamic>();
    } else {
      return <String, dynamic>{};  // Return an empty map if groupMap is not a Map.
    }
  }


  //for debugging
/*
  static int groupMessagesCount()  {
    if (_messages_group_box == null) {
      throw Exception('messages group box is not initialized.');
    }
    return _messages_group_box!.length;
  }

  static int getFatGroupsCount()  {
    if (_fat_groups_box == null) {
      throw Exception('Fat groups box is not initialized.');
    }
    return _fat_groups_box!.length;
  }
*/


  static Future<void> updateOrInsert_MessagesGroupCacheWatermark(
      String group_id, int createdAt) async {
    if (group_id.isEmpty) {
      throw Exception('Group ID cannot be blank.');
      return;
    }

    Box box;
    if (OG_HiveInterface._messages_group_cache_watermark_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_group_cache_watermark_box ??
          await Hive.openBox ('messages_group_cache_watermark');
    } else {
      box = await Hive.openBox ('messages_group_cache_watermark',
          path: hiveDbPath);
    }

    // If the group_id already exists in the box, update its value; otherwise, put a new entry.
    if (box.containsKey(group_id)) {
      box.put(group_id, {'createdAt': createdAt.toString()});
    } else {
      box.put(group_id, {'createdAt': createdAt.toString()});
    }
  }

  static Future<void> dumpCacheFatGroupWatermark(String partialGroupId) async {

    // the partialGrouId is just the actual event id, doesnt include the relay portion.. we want to dump the cache for the chat, so reset all relays on this group.
    if (partialGroupId.isEmpty) {
      throw Exception('Partial Group ID cannot be blank.');
      return;
    }

    Box box;
    if (OG_HiveInterface._messages_fat_group_cache_watermark_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_fat_group_cache_watermark_box ??
          await Hive.openBox('messages_fat_group_cache_watermark');
    } else {
      box = await Hive.openBox('messages_fat_group_cache_watermark', path: hiveDbPath);
    }

    // If the group_id partially matches any keys in the box, update its value to "0"
    box.keys.where((key) => key.toString().contains(partialGroupId)).forEach((matchingKey) {
      box.put(matchingKey, {'createdAt': '0'});
    });
  }


  static Future<void> updateOrInsert_MessagesFatGroupCacheWatermark(
      String group_id, int createdAt, ) async {
    if (group_id.isEmpty) {
      throw Exception('Group ID cannot be blank.');
      return;
    }

    Box box;
    if (OG_HiveInterface._messages_fat_group_cache_watermark_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_fat_group_cache_watermark_box ??
          await Hive.openBox ('messages_fat_group_cache_watermark');
    } else {
      box = await Hive.openBox ('messages_fat_group_cache_watermark',
          path: hiveDbPath);
    }

    // If the group_id already exists in the box, update its value; otherwise, put a new entry.
    if (box.containsKey(group_id)) {
      box.put(group_id, {'createdAt': createdAt.toString()});
    } else {
      box.put(group_id, {'createdAt': createdAt.toString()});
    }
  }

  static Future<void> updateOrInsert_Chosen_Alias(String? alias) async {
    Box box;
    if (OG_HiveInterface._chosen_alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._chosen_alias_box ?? await Hive.openBox('chosen_alias');
    } else {
      box = await Hive.openBox('chosen_alias', path: hiveDbPath);
    }
    if (box.length > 0) {
      //rowExists = True;
      final newMap = {'alias':alias};
      box.putAt(0, newMap);
    }
    else {

      final newRow = {'alias': alias};
      box.add(newRow);
    }
  }


  static Future<List> getListofRelays() async {
    Box box;
    if (OG_HiveInterface._relays_box?.isOpen ?? false) {
      box = OG_HiveInterface._relays_box  ?? await Hive.openBox('relays');
    } else {
      box = await Hive.openBox('relays', path: hiveDbPath);
    }
    final rows = box.values.where((row) => row['relay'] != null);
    return rows.toList(); // convert the Iterable to a List and return it
  }


  static Future<List> getListofAliases() async {

    Box box;
    if (OG_HiveInterface._alias_box?.isOpen  ?? false) {
      box = OG_HiveInterface._alias_box  ?? await Hive.openBox('aliases');
    } else {
      box = await Hive.openBox('aliases', path: hiveDbPath);
    }
    final rows = box.values.where((row) => row['alias'] != null);

    List retval = rows.toList(); // convert the Iterable to a List and return it
    return retval;
 }

  static Future<String> getData_PubkeyFromAlias(String alias) async {
    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false ) {
      box = OG_HiveInterface._alias_box  ?? await Hive.openBox('aliases');
    } else {
      box = await Hive.openBox('aliases',path: hiveDbPath);
    }
    final aliasMap = box.values.firstWhere(
          (map) => map['alias'] == alias,
      orElse: () => null,
    );
    if (aliasMap == null) {
      // Handle the case where the alias is not found in the database.
      return "";
    }
    return aliasMap['pubkey'];
  }


  static Future<String> getData_PrivkeyFromAlias(String alias) async {
    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false ) {
      box = OG_HiveInterface._alias_box  ?? await Hive.openBox('aliases');
    } else {
      box = await Hive.openBox('aliases',path: hiveDbPath);
    }
    final aliasMap = box.values.firstWhere(
          (map) => map['alias'] == alias,
      orElse: () => null,
    );
    if (aliasMap == null) {
      // Handle the case where the alias is not found in the database.
      return "";
    }
    return aliasMap['privkey'];
  }


  static Future<String> getData_AliasFromPubkey(String pubkey) async {
    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._alias_box  ?? await Hive.openBox('aliases');
    } else {
      box = await Hive.openBox('aliases',path: hiveDbPath);
    }
    final aliasMap = box.values.firstWhere(
          (map) => map['pubkey'] == pubkey,
      orElse: () => null,
    );
    if (aliasMap == null) {
      // Handle the case where the alias is not found in the database.
      return "";
    }
    return aliasMap['alias'];
  }

///////FETCH FRENDS DATA


  static Future<List> getListofFriends() async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box  ?? await Hive.openBox('friends');
    } else {
      box = await Hive.openBox('friends', path: hiveDbPath);
    }
    final rows = box.values.where((row) => row['friend'] != null);
    return rows.toList(); // convert the Iterable to a List and return it
  }



  static Future<List> getListofGroups() async {
    Box box;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._groups_box  ?? await Hive.openBox('groups');
    } else {
      box = await Hive.openBox('groups', path: hiveDbPath);
    }
    final rows = box.values.where((row) => row['group'] != null);
    return rows.toList(); // convert the Iterable to a List and return it
  }

  static Future<List> getListofFatGroups() async {

    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box  ?? await Hive.openBox('fat_groups');
    } else {
      box = await Hive.openBox('fat_groups', path: hiveDbPath);
    }
    final rows = box.values.where((row) => row['fat_group'] != null);
    return rows.toList(); // convert the Iterable to a List and return it
  }

  static Future<String> getData_PubekyFromFriend(String friend) async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box  ?? await Hive.openBox('friends');
    } else {
      box = await Hive.openBox('friends',path: hiveDbPath);
    }
    final friendMap = box.values.firstWhere(
          (map) => map['friend'] == friend,
      orElse: () => null,
    );
    if (friendMap == null) {
      // Handle the case where the alias is not found in the database.
      return "";
    }
    return friendMap['pubkey'];
  }


  static Future<String> getData_FriendFromPubkey(String pubkey) async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box  ?? await Hive.openBox('friends');
    } else {
      box = await Hive.openBox('friends',path: hiveDbPath);
    }
    final friendMap = box.values.firstWhere(
          (map) => map['pubkey'] == pubkey,
      orElse: () => null,
    );
    if (friendMap == null) {
      // Handle the case where the alias is not found in the database.
      return "";
    }
    return friendMap['friend'];
  }

  static Future<Map<String, dynamic>> getData_FriendMapFromPubkey(String pubkey) async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box ?? await Hive.openBox('friends');
    } else {
      box = await Hive.openBox('friends', path: hiveDbPath);
    }
    final friendMap = box.values.firstWhere(
          (map) => map['pubkey'] == pubkey,
      orElse: () => null,
    );
    if (friendMap == null) {
      // Handle the case where the alias is not found in the database.
      return {};
    }
    return friendMap.cast<String, dynamic>();
  }

  static Future<void> addData_UpdateConfigSettings(
      {String? wallpaper,
        String? timezone,
        bool? verify_signatures,
        int? events_per_query}) async {
    Box box;
    if (OG_HiveInterface._config_settings_box?.isOpen ?? false) {
      box = OG_HiveInterface._config_settings_box ?? await Hive.openBox('config_settings');
    } else {
      box = await Hive.openBox('config_settings', path: hiveDbPath);
    }

    Map<String, dynamic> updatedSettings = {};

    // Check if there's an existing entry in the box
    if (box.isNotEmpty) {
      updatedSettings = box.getAt(0).cast<String, dynamic>();
    }

    // Update the existing settings map with the new values, if provided
    if (wallpaper != null) {
      updatedSettings['wallpaper'] = wallpaper;
    }
    if (timezone != null) {
      updatedSettings['timezone'] = timezone;
    }
    if (verify_signatures != null) {
      updatedSettings['verify_signatures'] = verify_signatures;
    }
    if (events_per_query != null) {
      updatedSettings['events_per_query'] = events_per_query;
    }

    // Put the updated settings into the box
    if (box.isNotEmpty) {
      await box.putAt(0, updatedSettings);
    } else {
      await box.add(updatedSettings);
    }
  }


  static Future<Map<String, dynamic>> getData_ConfigSettings({String myHiveDbPath = ""} ) async {

    if (myHiveDbPath != "")  {
      hiveDbPath = myHiveDbPath;
    }

    Box box;
    if (OG_HiveInterface._config_settings_box?.isOpen ?? false) {
      box = OG_HiveInterface._config_settings_box ?? await Hive.openBox('config_settings');
    } else {
      box = await Hive.openBox('config_settings', path: hiveDbPath);
    }

    // If the box is empty, return an empty map
    if (box.isEmpty) {
      return {};
    }

    // Combine all the entries in the box into a single map
    final configSettingsMap = box.values.fold<Map<String, dynamic>>(
      {},
          (acc, map) => acc..addAll(map.cast<String, dynamic>()),
    );

    return configSettingsMap;
  }


  static Future<Map<String, dynamic>> getData_FatGroupMap(String fatGroupId) async {
    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box ?? await Hive.openBox('fat_groups');
    } else {
      box = await Hive.openBox('fat_groups', path: hiveDbPath);
    }
    final fatGroupsMap = box.values.firstWhere(
          (map) => map['fat_group'] == fatGroupId,
      orElse: () => null,
    );
    if (fatGroupsMap == null) {
      // Handle the case where the alias is not found in the database.
      return {};
    }
    return fatGroupsMap.cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getData_AliasMapFromName(String aliasName) async {
    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._alias_box ?? await Hive.openBox('aliases');
    } else {
      box = await Hive.openBox('aliases', path: hiveDbPath);
    }
    final aliasMap = box.values.firstWhere(
          (map) => map['alias'] == aliasName,
      orElse: () => null,
    );
    if (aliasMap == null) {
      // Handle the case where the alias is not found in the database.
      return {};
    }
    return aliasMap.cast<String, dynamic>();
  }



  static Future<void> deleteFriendByPubkey(String pubkey) async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box ?? await Hive.openBox('friends', path: hiveDbPath);
    } else {
      box = await Hive.openBox('friends', path: hiveDbPath);
    }
    final rowsToDelete = <int>[];
    for (int i = 0; i < box.length; i++) {
      final row = box.getAt(i);
      if (row != null) {
        final pubkeyValue = row["pubkey"];
        if (pubkeyValue != null && pubkeyValue == pubkey) {
          rowsToDelete.add(i);
        }
      }
    }
    rowsToDelete.reversed.forEach((index) => box.deleteAt(index));
    await box.compact();
  }



  /////---END FETCH FREINDS DATA


  static Future<Map<String, String>> getData_Chosen_Alias_Map() async {

    Box box;
    if (OG_HiveInterface._chosen_alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._chosen_alias_box  ?? await Hive.openBox('chosen_alias');
    } else {
      box = await Hive.openBox('chosen_alias', path: hiveDbPath);
    }

    var mapValue = box.get(0);

    if (mapValue != null && mapValue.containsKey('alias')) {
      return Map<String, String>.from(mapValue);
    } else {
      return {}; // Return an empty map instead of null
    }
  }



  static List getRowsWhereCol1Equals(String col1Value) {
    final box = Hive.box('myBox'); // open the Hive box

    // use the .values property of the box to get all rows (i.e., maps) in "table1"
    final rows = box.values.where((row) => row['table1'] != null && row['table1']['col1'] == col1Value);

    return rows.toList(); // convert the Iterable to a List and return it
  }


  static Future<List<Map<String, String>>> getMessagesForRelay(String relay) async {
    Box box;
    if (OG_HiveInterface._messages_relay_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_relay_box ?? await Hive.openBox('messages_relay');
    } else {
      box = await Hive.openBox('messages_relay', path: hiveDbPath);
    }

    String keyPrefix = '${relay}_';
    List<Map<String, String>> messages = [];

    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        messages.add(box.get(key).cast<String, String>());
      }
    }

    return messages;
  }


  static Future<List<Map<String, String>>> getMessagesForFatGroup(String group) async {
    Box box;
    if (OG_HiveInterface._messages_fat_group_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_fat_group_box ?? await Hive.openBox('messages_fat_group');
    } else {
      box = await Hive.openBox('messages_fat_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    List<Map<String, String>> messages = [];

    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        messages.add(box.get(key).cast<String, String>());
      }
    }

    return messages;
  }



  static Future<List<Map<String, String>>> getMessagesForGroup(String group) async {
    Box box;
    if (OG_HiveInterface._messages_group_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_group_box ?? await Hive.openBox('messages_group');
    } else {
      box = await Hive.openBox('messages_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    List<Map<String, String>> messages = [];

    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        messages.add(box.get(key).cast<String, String>());
      }
    }

    return messages;
  }



  static Future<List<Map<String, String>>> getMessagesForFriend(String pubkey) async {
    Box box;
    if (OG_HiveInterface._messages_friend_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_friend_box ?? await Hive.openBox('messages_friend');
    } else {
      box = await Hive.openBox('messages_friend', path: hiveDbPath);
    }

    String keyPrefix = '${pubkey}_';
    List<Map<String, String>> messages = [];

    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        messages.add(box.get(key).cast<String, String>());
      }
    }

    return messages;
  }



  static Future<void> removeMessagesForFriend(String pubkey) async {
    Box box;
    if (_messages_friend_box?.isOpen ?? false) {
      box = _messages_friend_box ?? await Hive.openBox('messages_friend');
    } else {
      box = await Hive.openBox('messages_friend', path: hiveDbPath);
    }

    String keyPrefix = '${pubkey}_';
    List<dynamic> keysToRemove = [];

    // Find keys with the specified prefix
    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        keysToRemove.add(key);
      }
    }

    // Remove the keys
    for (var key in keysToRemove) {
      await box.delete(key);
    }
  }


  static Future<void> removeMessagesForFatGroup(String group) async {    Box box;
    if (_messages_fat_group_box?.isOpen ?? false) {
      box = _messages_fat_group_box ?? await Hive.openBox('messages_fat_group');
    } else {
      box = await Hive.openBox('messages_fat_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    List<dynamic> keysToRemove = [];

    // Find keys with the specified prefix
    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        keysToRemove.add(key);
      }
    }

    // Remove the keys
    for (var key in keysToRemove) {
      await box.delete(key);
    }
  }



  static Future<void> removeMessagesForGroup(String group) async {
    Box box;
    if (_messages_group_box?.isOpen ?? false) {
      box = _messages_group_box ?? await Hive.openBox('messages_group');
    } else {
      box = await Hive.openBox('messages_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    List<dynamic> keysToRemove = [];

    // Find keys with the specified prefix
    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        keysToRemove.add(key);
      }
    }

    // Remove the keys
    for (var key in keysToRemove) {
      await box.delete(key);
    }
  }


  static Future<void> removeMessagesForRelay(String relay) async {
    Box box;
    if (_messages_relay_box?.isOpen ?? false) {
      box = _messages_relay_box ?? await Hive.openBox('messages_relay');
    } else {
      box = await Hive.openBox('messages_relay', path: hiveDbPath);
    }

    String keyPrefix = '${relay}_';
    List<dynamic> keysToRemove = [];

    // Find keys with the specified prefix
    for (var key in box.keys) {
      if (key.toString().startsWith(keyPrefix)) {
        keysToRemove.add(key);
      }
    }

    // Remove the keys
    for (var key in keysToRemove) {
      await box.delete(key);
    }
  }


  static Future<void> addData_MessagesFriend(String keyPrefix, List<Map<String, String>> messages, {bool WipePreviousCacheforComposite = false}) async {
    //Key parameter expected to be in the format of userpubkey concatenated with underscore , concatendated with friend pubkey e.g. "userkey_friendkey"

    Box box;
    if (OG_HiveInterface._messages_friend_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_friend_box ?? await Hive.openBox('messages_friend');
    } else {
      box = await Hive.openBox('messages_friend', path: hiveDbPath);
    }

    if (WipePreviousCacheforComposite) {
      // Delete all rows with the specified prefix
      for (var key in box.keys) {
        if (key.toString().startsWith(keyPrefix)) {
          await box.delete(key);
        }
      }
    }

    // Insert new rows
    for (Map<String, String> message in messages) {
      String compositeKey = '${keyPrefix}_${message["id"]}';
      await box.put(compositeKey, message);
    }
  }


  static Future<void> addData_MessagesGroup(String group, List<Map<String, String>> messages, {bool WipePreviousCacheforComposite = false}) async {
    Box box;
    if (OG_HiveInterface._messages_group_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_group_box ?? await Hive.openBox('messages_group');
    } else {
      box = await Hive.openBox('messages_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    if (WipePreviousCacheforComposite) {
      // Delete all rows with the specified prefix
      for (var key in box.keys) {
        if (key.toString().startsWith(keyPrefix)) {
          await box.delete(key);
        }
      }
    }

    // Insert new rows
    for (Map<String, String> message in messages) {
      String compositeKey = '${group}_${message["id"]}';
      await box.put(compositeKey, message);
    }
  }

  static Future<void> addData_MessagesFatGroup(String group, List<Map<String, String>> messages, {bool WipePreviousCacheforComposite = false}) async {

    Box box;
    if (OG_HiveInterface._messages_fat_group_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_fat_group_box ?? await Hive.openBox('messages_fat_group');
    } else {
      box = await Hive.openBox('messages_fat_group', path: hiveDbPath);
    }

    String keyPrefix = '${group}_';
    if (WipePreviousCacheforComposite) {
      // Delete all rows with the specified prefix
      for (var key in box.keys) {
        if (key.toString().startsWith(keyPrefix)) {
          await box.delete(key);
        }
      }
    }

    // Insert new rows
    for (Map<String, String> message in messages) {
      String compositeKey = '${group}_${message["id"]}';
      await box.put(compositeKey, message);
    }
  }


  static Future<void> addData_MessagesRelay(String relay, List<Map<String, String>> messages, {bool WipePreviousCacheforComposite = false}) async {
    Box box;
    if (OG_HiveInterface._messages_relay_box?.isOpen ?? false) {
      box = OG_HiveInterface._messages_relay_box ?? await Hive.openBox('messages_relay');
    } else {
      box = await Hive.openBox('messages_relay', path: hiveDbPath);
    }

    String keyPrefix = '${relay}_';
    if (WipePreviousCacheforComposite) {
      // Delete all rows with the specified prefix
      for (var key in box.keys) {
        if (key.toString().startsWith(keyPrefix)) {
          await box.delete(key);
        }
      }
    }

    // Insert new rows
    for (Map<String, String> message in messages) {
      String compositeKey = '${relay}_${message["id"]}';
      await box.put(compositeKey, message);
    }
  }


  static Future<void> addData_Relays(String relay, String left_panel_position) async {

    if (relay == "") {

      throw Exception('Relay cannot be blank.');
      return;
    }
    if (relay.length > 200) {

      throw Exception('Relay cannot be longer than 200 characters.');
      return;
    }

    Box box;
    if (OG_HiveInterface._relays_box?.isOpen ?? false) {
      box = OG_HiveInterface._relays_box  ?? await Hive.openBox('relays');
    } else {
      box = await Hive.openBox('relays',path: hiveDbPath);
    }

    final existingRelays = box.values.firstWhereOrNull(
          (map) => map['relay'] == relay,
    );

    if (existingRelays == null) {
      await box.add({'relay': relay, 'left_panel_position': left_panel_position});
    } else {
      throw Exception('You already have this relay.');
    }
  }


  static Future<void> addData_Groups(String group, String left_panel_position, {required Map<String, dynamic> aux_data}) async {

  // THIS FUNCTION WILL CHANGE...THERE IS NO GROUP NAME PER SE.  WE FETCH GROUP AND SET name, desc from link.
    if (group == "") {

      throw Exception('Relay cannot be blank.');
      return;
    }
    if (group.length > 200) {

      throw Exception('Relay cannot be longer than 200 characters.');
      return;
    }

    Box box;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._groups_box  ?? await Hive.openBox('groups');
    } else {
      box = await Hive.openBox('groups',path: hiveDbPath);
    }

    final existingGroup = box.values.firstWhereOrNull(
          (map) => map['group'] == group,
    );

    if (existingGroup == null) {
      await box.add({
        'group': group,
        'left_panel_position': left_panel_position,
        'id': aux_data['id'],
        'pubkey': aux_data['pubkey'],
        'created_at': aux_data['created_at'],
        'kind': aux_data['kind'],
        'tags': jsonEncode(aux_data['tags']),
        'content': jsonEncode(aux_data['content']),
        'sig': aux_data['sig']
      });

    } else {
      throw Exception('You already have this group.');
    }
  }

  static Future<void> addData_FatGroups(String group, String left_panel_position, {required Map<String, dynamic> aux_data}) async {
    if (group == "") {

      throw Exception('Relay cannot be blank.');
      return;
    }
    if (group.length > 200) {

      throw Exception('Gropuname cannot be longer than 200 characters.');
      return;
    }

    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box  ?? await Hive.openBox('fat_groups');
    } else {
      box = await Hive.openBox('fat_groups',path: hiveDbPath);
    }

    final existingGroup = box.values.firstWhereOrNull(
          (map) => map['fat_group'] == group,
    );

    if (existingGroup == null) {
      var data = {
        'fat_group': group,
        'left_panel_position': left_panel_position,
        'id': aux_data['id'],
        'pubkey': aux_data['pubkey'],
        'created_at': aux_data['created_at'],
        'kind': aux_data['kind'],
        'tags': jsonEncode(aux_data['tags']),
        'content': jsonEncode(aux_data['content']),
        'sig': aux_data['sig'],
        'metadata_relays': aux_data['metadata_relays']
      };
      await box.add(data);
    }else {
      throw Exception('You already have this group.');
    }
  }

  static Future<void> setLeftPanelPositionFriend(String pubkey, String left_panel_position) async {
    Box box;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box = OG_HiveInterface._friends_box ?? await Hive.openBox('friends');
    } else {
      box = await Hive.openBox('friends', path: hiveDbPath);
    }

    final existingGroupKey = box.keys.firstWhereOrNull(
          (key) => box.get(key)['pubkey'] == pubkey,
    );

    if (existingGroupKey != null) {
      await box.put(existingGroupKey, {
        ...box.get(existingGroupKey),
        'left_panel_position': left_panel_position,
      });
    } else {
      throw Exception('Contact not found.');
    }
  }

  static Future<void> setLeftPanelPositionGroup(String group, String left_panel_position) async {

    Box box;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._groups_box ?? await Hive.openBox('groups');
    } else {
      box = await Hive.openBox('groups', path: hiveDbPath);
    }

    final existingGroupKey = box.keys.firstWhereOrNull(
          (key) => box.get(key)['group'] == group,
    );

    if (existingGroupKey != null) {
      await box.put(existingGroupKey, {
        ...box.get(existingGroupKey),
        'left_panel_position': left_panel_position,
      });
    } else {
      throw Exception('Group not found.');
    }
  }

  static Future<void> setLeftPanelPositionFatGroup(String group, String left_panel_position) async {

    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box ?? await Hive.openBox('fat_groups');
    } else {
      box = await Hive.openBox('fat_groups', path: hiveDbPath);
    }

    final existingGroupKey = box.keys.firstWhereOrNull(
          (key) => box.get(key)['fat_group'] == group,
    );

    if (existingGroupKey != null) {
      await box.put(existingGroupKey, {
        ...box.get(existingGroupKey),
        'left_panel_position': left_panel_position,
      });
    } else {
      throw Exception('Group not found.');
    }
  }

  static Future<void> setLeftPanelPositionRelay(String relay, String left_panel_position) async {
    Box box;
    if (OG_HiveInterface._relays_box?.isOpen ?? false) {
      box = OG_HiveInterface._relays_box ?? await Hive.openBox('relays');
    } else {
      box = await Hive.openBox('relayss', path: hiveDbPath);
    }

    final existingGroupKey = box.keys.firstWhereOrNull(
          (key) => box.get(key)['relay'] == relay,
    );

    if (existingGroupKey != null) {
      await box.put(existingGroupKey, {
        ...box.get(existingGroupKey),
        'left_panel_position': left_panel_position,
      });
    } else {
      throw Exception('Relay not found.');
    }
  }

  static Future<bool> groupExists(String group) async {
    Box box;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._groups_box ?? await Hive.openBox('groups');
    } else {
      box = await Hive.openBox('groups', path: hiveDbPath);
    }

    final existingGroup = box.values.firstWhereOrNull(
          (map) => map['group'] == group,
    );

    return existingGroup != null;
  }



  static Future<bool> fatGroupExists(String group) async {
    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box ?? await Hive.openBox('fat_groups');
    } else {
      box = await Hive.openBox('fat_groups', path: hiveDbPath);
    }

    final existingGroup = box.values.firstWhereOrNull(
          (map) => map['fat_group'] == group,
    );

    return existingGroup != null;
  }

  static Future<String> get_Highest_Left_Panel_Position() async {



    Box box;
    if (OG_HiveInterface._relays_box?.isOpen ?? false) {
      box = OG_HiveInterface._relays_box  ?? await Hive.openBox('relays');
    } else {
      box = await Hive.openBox('relays',path: hiveDbPath);
    }


    Box box2;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box2 = OG_HiveInterface._groups_box  ?? await Hive.openBox('groups');
    } else {
      box2 = await Hive.openBox('groups',path: hiveDbPath);
    }


    Box box3;
    if (OG_HiveInterface._friends_box?.isOpen ?? false) {
      box3 = OG_HiveInterface._friends_box  ?? await Hive.openBox('friends');
    } else {
      box3 = await Hive.openBox('friends',path: hiveDbPath);
    }


    int maxLeftPanelPosition = 0;


    for (Box currentBox in [box, box2, box3]) {
      List<dynamic> values = currentBox.values.toList();
      for (dynamic value in values) {
        Map<String, dynamic> valueMap = Map<String, dynamic>.from(value); // Convert the value to Map<String, dynamic> without casting
        String? leftPanelPositionString = valueMap['left_panel_position'];
        if (leftPanelPositionString != null) {
          int leftPanelPosition = int.tryParse(leftPanelPositionString) ?? 0;
          maxLeftPanelPosition = max(maxLeftPanelPosition, leftPanelPosition);
        }
      }
    }


    return maxLeftPanelPosition.toString();
  }


  static Future<void> addData_Aliases(String alias, String privkey, String pubkey) async {
    alias = alias.trim();
    if (alias == "") {

    throw Exception('Alias name cannot be blank.');
    return;
    }
    if (alias.length > 30) {

      throw Exception('Alias name cannot be longer than 30 characters.');
      return;
    }
    RegExp regExp = new RegExp(r'^[a-zA-Z0-9 _-]+$');

    if (!regExp.hasMatch(alias)) {

      throw Exception('Alias name should contain only letters and numbers.');
      return;
    }

    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._alias_box ?? await Hive.openBox('aliases', path: hiveDbPath);
    } else {
      box = await Hive.openBox('aliases', path: hiveDbPath);
    }

    // Determine an Ostrich icon.
    int rowCount = box.length;
    int remainder = rowCount % 6;
    int customOstrich = remainder + 1;
    String customOstrichString = customOstrich.toString();


    final existingItem = box.values.firstWhereOrNull(
          (item) => item['alias'] == alias || item['pubkey'] == pubkey,
    );

    Map<String, String> existingItemMap;
    if (existingItem == null) {
      existingItemMap = <String, String>{};
    } else {
      existingItemMap =
          Map<String, dynamic>.from(existingItem).cast<String, String>();
    }

    if (existingItemMap.isEmpty) {
      await box.add({'alias': alias, 'privkey': privkey, 'pubkey': pubkey, 'customOstrich': customOstrichString} );

      //  Update Chosen Alias if this is the first row in the 'aliases' box
      if (box.length == 1) {
        await updateOrInsert_Chosen_Alias(alias);
      }

    } else {
      throw Exception('You already have an alias with this pubkey or name.');
    }
  }



  static Future<void> updateData_Friends_UpdateNameandRelay(String pubkey, String newFriendName, String newRelayForDM) async {

    newFriendName=newFriendName.trim();

    return _lock.synchronized(() async {
      if (newFriendName == "") {
        throw Exception('Contact name cannot be blank.');
      }
      if (newFriendName.length > 30) {
        throw Exception('Contact name cannot be longer than 30 characters.');
      }

      RegExp regExp = new RegExp(r'^[a-zA-Z0-9 _-]+$');
      if (!regExp.hasMatch(newFriendName)) {
        throw Exception('Contact name should contain only letters and numbers.');
      }

      Box box;
      if (OG_HiveInterface._friends_box?.isOpen ?? false) {
        box = OG_HiveInterface._friends_box ?? await Hive.openBox('friends', path: hiveDbPath);
      } else {
        box = await Hive.openBox('friends', path: hiveDbPath);
      }

      final existingItemKey = box.keys.firstWhereOrNull(
            (key) => box.get(key)['pubkey'] == pubkey,
      );

      if (existingItemKey == null) {
        throw Exception('No contact found with the provided pubkey.');
      }

      Map<String, dynamic> existingItemMap = box.get(existingItemKey).cast<String, dynamic>();
      existingItemMap['friend'] = newFriendName;
      existingItemMap['relay_for_DM'] = newRelayForDM;
      await box.put(existingItemKey, existingItemMap);
    });
  }


  static Future<void> addData_Friends(String friend, String pubkey, String avatar_style, String left_panel_position, String relay_for_DM) async {
    friend=friend.trim();
    return _lock.synchronized(() async {
      if (friend == "") {
        throw Exception('Contact name cannot be blank.');
      }
      if (friend.length > 30) {
        throw Exception('Contact name cannot be longer than 30 characters.');
      }

      RegExp regExp = new RegExp(r'^[a-zA-Z0-9 _-]+$');
      if (!regExp.hasMatch(friend)) {
        throw Exception('Contact name should contain only letters and numbers.');
      }
      Box box;
      if (OG_HiveInterface._friends_box?.isOpen  ?? false) {
        box = OG_HiveInterface._friends_box ?? await Hive.openBox('friends', path: hiveDbPath);;
      } else {
        box = await Hive.openBox('friends', path: hiveDbPath);
      }

      final existingItem = box.values.firstWhereOrNull(
            (item) => item['friend'] == friend || item['pubkey'] == pubkey,
      );

      Map<String, String> existingItemMap;
      if (existingItem == null) {
        existingItemMap = <String, String>{};
      } else {
        existingItemMap = Map<String, dynamic>.from(existingItem).cast<String, String>();
      }

      if (existingItemMap.isEmpty) {
        // Include the image_name in the map we store in the Hive box
        await box.add({'friend': friend, 'pubkey': pubkey, 'avatar_style': avatar_style, 'left_panel_position': left_panel_position, 'relay_for_DM': relay_for_DM});
      } else {
        throw Exception('You already have a contact with this pubkey or name.');
      }
    });
  }



  static Future<void> deleteAliasbyName(String alias) async {
    Box box;
    if (OG_HiveInterface._alias_box?.isOpen ?? false) {
      box = OG_HiveInterface._alias_box ?? await Hive.openBox('aliases', path: hiveDbPath);
    } else {
      box = await Hive.openBox('aliases', path: hiveDbPath);
    }
    final rowsToDelete = <int>[];
    for (int i = 0; i < box.length; i++) {
      final row = box.getAt(i);
      if (row != null) {
        final aliasValue = row["alias"];
        if (aliasValue != null && aliasValue == alias) {
          rowsToDelete.add(i);
        }
      }
    }
    rowsToDelete.reversed.forEach((index) => box.deleteAt(index));
    await box.compact();

    // Additional tasks:
    // 1. Check the value of Chosen Alias
    Map<String, String> chosenAliasMap = await getData_Chosen_Alias_Map();
    String? chosenAlias = chosenAliasMap['alias'];

    // 2. If the value of Chosen Alias is the same as the Alias name we just deleted, update Chosen Alias
    if (chosenAlias == alias) {
      // 3. Arbitrarily pick a new alias from the 'aliases' box, or use an empty string if the box is empty
      String newChosenAlias = '';
      if (box.length > 0) {
        newChosenAlias = box.getAt(0)['alias'] ?? '';
      }
      await updateOrInsert_Chosen_Alias(newChosenAlias);
    }
  }



  static Future<void> deleteRelay(String relay) async {
    Box box;
    if (OG_HiveInterface._relays_box?.isOpen ?? false) {
      box = OG_HiveInterface._relays_box ?? await Hive.openBox('relays', path: hiveDbPath);
    } else {
      box = await Hive.openBox('relays',path: hiveDbPath);
    }
    final rowsToDelete = <int>[];
    for (int i = 0; i < box.length; i++) {
      final row = box.getAt(i);
      if (row != null) {
        final relayValue = row["relay"];
        if (relayValue != null && relayValue == relay) {
          rowsToDelete.add(i);
        }
      }
    }
    rowsToDelete.reversed.forEach((index) => box.deleteAt(index));
    await box.compact();
  }

  static Future<void> deleteFatGroup(String group) async {
    Box box;
    if (OG_HiveInterface._fat_groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._fat_groups_box ?? await Hive.openBox('fat_groups', path: hiveDbPath);
    } else {
      box = await Hive.openBox('fat_groups',path: hiveDbPath);
    }
    final rowsToDelete = <int>[];
    for (int i = 0; i < box.length; i++) {
      final row = box.getAt(i);
      if (row != null) {
        final groupValue = row["fat_group"];
        if (groupValue != null && groupValue == group) {
          rowsToDelete.add(i);
        }
      }
    }
    rowsToDelete.reversed.forEach((index) => box.deleteAt(index));
    await box.compact();
  }

  static Future<void> deleteGroup(String group) async {
    Box box;
    if (OG_HiveInterface._groups_box?.isOpen ?? false) {
      box = OG_HiveInterface._groups_box ?? await Hive.openBox('groups', path: hiveDbPath);
    } else {
      box = await Hive.openBox('groups',path: hiveDbPath);
    }
    final rowsToDelete = <int>[];
    for (int i = 0; i < box.length; i++) {
      final row = box.getAt(i);
      if (row != null) {
        final groupValue = row["group"];
        if (groupValue != null && groupValue == group) {
          rowsToDelete.add(i);
        }
      }
    }
    rowsToDelete.reversed.forEach((index) => box.deleteAt(index));
    await box.compact();
  }

}  //END OF CLASS HIVE INTERFACE.

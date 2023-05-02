
import 'bip340.dart';
import 'og_hive_interface.dart';
import 'dart:math';
import 'global_config.dart';
import 'bech32.dart';
import 'package:convert/convert.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'nip04.dart';
import 'package:flutter/foundation.dart';

// Class to handle some nostr-specific functionality.
class nostr_core {

  static Future<void> init() async {
  }


  static List<int> convertBits(List<int> data, int fromBits, int toBits, bool pad) {
    int acc = 0;
    int bits = 0;
    List<int> result = [];
    int maxv = (1 << toBits) - 1;

    for (int value in data) {
      if (value < 0 || value >> fromBits != 0) {
        throw Exception("Invalid data value: $value");
      }
      acc = (acc << fromBits) | value;
      bits += fromBits;

      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
      throw Exception("Invalid padding");
    }

    return result;
  }

  static String hexToBech32(String hex, String prefix) {
    List<int> data = List<int>.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
    List<int> convertedData = convertBits(data, 8, 5, true);
    Bech32 bech32Data = Bech32(prefix, convertedData);
    String retval = bech32.encode(bech32Data);
    return retval;
  }

  static String bech32ToHex(String bech32Address) {
    Bech32 decoded = bech32.decode(bech32Address);
    List<int> data = convertBits(decoded.data, 5, 8, false);
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }


static Future<String> decipher_kind04_message(String friend_pubkey, String ciphertext) async {

  // First, get Chosen Alias pubkey and privkey
  Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
  String alias = chosenAliasData?['alias'] ?? '';

  String privkey ="";
  try {
    privkey = await OG_HiveInterface.getData_PrivkeyFromAlias(alias);
  } catch(e) {
    print ('failed to get privatekey during nip04 decryption: $e');
    return "";
  }

  String plaintext_message ="";
  try {
    plaintext_message = Nip04.decrypt(privkey, friend_pubkey, ciphertext);
  } catch (e) {
    print ('something went wrong decrypting the nip04 message: $e');
  }
  return plaintext_message;
}

  static Future<String> create_kind04_post(String friend_pubkey, String message) async {

    //1. Get Chosen Alias pubkey and privkey
    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String alias = chosenAliasData?['alias'] ?? '';

    String pubkey ="";
    String privkey ="";
    pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);
    privkey = await OG_HiveInterface.getData_PrivkeyFromAlias(alias);


    // Define the created_at
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int created_at = currentTimeStamp;

    //3. Build the tags
    List<List<String>> tags = [["p", friend_pubkey]];


    int kind =4;

    // Generate the event id

    String ciphertext="";
    try {
     ciphertext = Nip04.encrypt(privkey,friend_pubkey,message); }
    catch (e) {
      print ('Something went wrong encrypting a nip04 message. Message not sent.');
      return "";
    }

    // Encode the event
    List<dynamic> serializedEvent = generateSerializedEvent(pubkey, created_at, kind, tags, ciphertext);
    String serializedEventJson =  jsonEncode(serializedEvent);
    // Calculate the SHA256 hash of the serialized event
    Digest hash_object_id = sha256.convert(utf8.encode(serializedEventJson));
    String event_id = hash_object_id.toString();


   // Generate the sig
    Uint8List sig;
    Uint8List aux_rand = generateAuxRand();
    Uint8List event_id_bytes = Uint8List.fromList(hex.decode(event_id));
    Uint8List privkey_bytes = Uint8List.fromList(hex.decode(privkey));
    sig = bip340.schnorr_sign(event_id_bytes, privkey_bytes, aux_rand);
    String sig_string = hex.encode(sig);

    // Create the event as JSON and return it.
    String JSONpost = createJSONpost(event_id, pubkey, created_at, kind, tags, ciphertext, sig_string);
    return JSONpost;
  }

  static Future<String> create_kind42_post(String e_tag, String message, {String e_Tag_Reply="", String p_Tag_Reply = ""}) async {
    // Get Chosen Alias pubkey and privkey
    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String alias = chosenAliasData?['alias'] ?? '';

    String pubkey ="";
    String privkey ="";
    pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);
    privkey = await OG_HiveInterface.getData_PrivkeyFromAlias(alias);

    // Define the created_at
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int created_at = currentTimeStamp;

    // Build the tags
    List<List<String>> tags = [
      ["e", e_tag.trim(), "root"],
    ];

    if (e_Tag_Reply.isNotEmpty) {
      tags.add(["e", e_Tag_Reply, "reply"]);
    }

    if (p_Tag_Reply.isNotEmpty) {
      tags.add(["p", p_Tag_Reply]);
    }

    int kind = 42;

    //4. Generate the event id
    List<dynamic> serializedEvent = generateSerializedEvent(pubkey, created_at, kind, tags, message);
    String serializedEventJson = jsonEncode(serializedEvent);

    // Calculate the SHA256 hash of the serialized event
    Digest hash_object_id = sha256.convert(utf8.encode(serializedEventJson));
    String event_id = hash_object_id.toString();


    // Generate the sig
    Uint8List sig;
    Uint8List aux_rand = generateAuxRand();
    Uint8List event_id_bytes = Uint8List.fromList(hex.decode(event_id));
    Uint8List privkey_bytes = Uint8List.fromList(hex.decode(privkey));
    sig = bip340.schnorr_sign(event_id_bytes, privkey_bytes, aux_rand);
    String sig_string = hex.encode(sig);

    // Create the event as JSON and return it.
    String JSONpost = createJSONpost(event_id, pubkey, created_at, kind, tags, message, sig_string);
    return JSONpost;
  }  // END create kind 42 post.


  static Future<String> create_kind40_post(String name, String about) async {

    // Get Chosen Alias pubkey and privkey
    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String alias = chosenAliasData?['alias'] ?? '';

    String pubkey ="";
    String privkey ="";
    pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);
    privkey = await OG_HiveInterface.getData_PrivkeyFromAlias(alias);

    // Define the created_at
    int currentTimeStamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int created_at = currentTimeStamp;

    // Build the tags
    List<List<String>> tags = [];
    int kind = 40;

    Map<String, String> content = {
      'name': name,
      'about': about
    };

    String message = jsonEncode(content) ;

    // Generate the event id
    List<dynamic> serializedEvent = generateSerializedEvent(pubkey, created_at, kind, tags, message);
    String serializedEventJson = jsonEncode(serializedEvent);

    // Calculate the SHA256 hash of the serialized event
    Digest hash_object_id = sha256.convert(utf8.encode(serializedEventJson));
    String event_id = hash_object_id.toString();


    // Generate the sig
    Uint8List sig;
    Uint8List aux_rand = generateAuxRand();
    Uint8List event_id_bytes = Uint8List.fromList(hex.decode(event_id));
    Uint8List privkey_bytes = Uint8List.fromList(hex.decode(privkey));
    sig = bip340.schnorr_sign(event_id_bytes, privkey_bytes, aux_rand);
    String sig_string = hex.encode(sig);

    // Create the event as JSON and return it.
    String JSONpost = createJSONpost(event_id, pubkey, created_at, kind, tags, message, sig_string);
    return JSONpost;
  }  // END create kind 40 post.





  static String createJSONpost(String id, String pubkey, int createdAt, int kind, List<List<String>> tags, String content, String sig) {
    Map<String, dynamic> event = {
      "id": id,
      "pubkey": pubkey,
      "created_at": createdAt,
      "kind": kind,
      "tags": tags,
      "content": content,
      "sig": sig
    };

    List<dynamic> eventData = ["EVENT", event];
    return jsonEncode(eventData);
  }

  static List<dynamic> generateSerializedEvent(String pubkey, int createdAt, int kind, List<List<String>> tags, String content) {
    return [
      0,
      pubkey.toLowerCase(),
      createdAt,
      kind,
      tags,
      content
    ];
  }

  static String generateRandomSubscriptionString() {
    Random random = Random();
    String result = '';
    for (int i = 0; i < 64; i++) {
      result += random.nextInt(10).toString();
    }
    return result;
  }


  static Uint8List generateAuxRand() {

    // GENERATE RANDOM 32 BYTES FOR SCHNORR SIGNATURE
    final random = Random.secure();
    final auxRand = Uint8List(32);

    for (int i = 0; i < 32; i++) {
      auxRand[i] = random.nextInt(256);
    }
    return auxRand;
  }

  static String constructJSON_fetch_kind_40s() {
    final globalConfig = GlobalConfig();
    int limit = globalConfig.message_limit;
    String subscription_id = generateRandomSubscriptionString();

    List<dynamic> requestData = [
      'REQ',
      subscription_id,
      {
        'kinds': [40],
        'limit': limit,
      },
    ];

    String request = jsonEncode(requestData);
    return request;
  }


  static String constructJSON_fetch_kind_42s(String e_tag) {
    final globalConfig = GlobalConfig();
    int limit = globalConfig.message_limit;
    String subscription_id = generateRandomSubscriptionString();

    List<dynamic> requestData = [
      'REQ',
      subscription_id,
      {
        'kinds': [42],
        '#e': [e_tag],
        'limit': limit,
      },
    ];

    String request = jsonEncode(requestData);
    return request;
  }


  static String constructJSON_fetch_kind_04s(String friend_pubkey, String user_pubkey) {
    final globalConfig = GlobalConfig();
    int limit = globalConfig.message_limit;
    String subscription_id = generateRandomSubscriptionString();

    List<dynamic> requestData = [
      'REQ',
      subscription_id,
      {
        'kinds': [4],
        '#p': [user_pubkey],
        'authors' : [friend_pubkey],
        'limit': limit,
      },
    ];

    String request = jsonEncode(requestData);
    return request;
  }


  static Future<List<Map<String, String>>> processWebSocketData(Map<String, dynamic> args) async {
    List<String> fetchedData = [];
    if (args["fetchedData"] != null ) {
      fetchedData = args["fetchedData"]!;
    }
    String hiveDbPath = "";
    if (args["hiveDbPath"] != null ) {
      hiveDbPath = args["hiveDbPath"]!;
    }

    List<Map<String, String>> processedData = [];


    for (String string in fetchedData) {
   // fetchedData.forEach((string) {
      List<dynamic> data = jsonDecode(string);
      if (data.length > 2 && data[2] is Map<String, dynamic>) {
        Map<String, dynamic> eventData = data[2];
        if (eventData['id'] != null) {
          // Serialize the event data
          List<dynamic> serializedEventData = [
            0,
            eventData['pubkey'],
            eventData['created_at'],
            eventData['kind'],
            eventData['tags'],
            eventData['content']
          ];

          String serializedEventJson = jsonEncode(serializedEventData);

          // Calculate the SHA256 hash of the serialized event data
          Digest hash_object_id = sha256.convert(utf8.encode(serializedEventJson));
          String event_id = hash_object_id.toString();


          // Check if the id is the right hash of the other items
          if (event_id == eventData['id']) {
            // Verify the signature
            Uint8List msg = Uint8List.fromList(hex.decode(event_id));
            Uint8List pubkey = Uint8List.fromList(hex.decode(eventData['pubkey']));
            Uint8List sig = Uint8List.fromList(hex.decode(eventData['sig']));


            // Get the config settings
            Map<String, dynamic> configSettings = await OG_HiveInterface.getData_ConfigSettings(myHiveDbPath: hiveDbPath);
            // Check if signature verification is enabled in the settings
            bool verifySignatures = configSettings['verify_signatures'] ?? true;
            // If signature verification is enabled, call the schnorr_verify function, otherwise set isSignatureValid to true
            bool isSignatureValid = verifySignatures ? bip340.schnorr_verify(msg, pubkey, sig) : true;


            //USEFUL FOR TESTING IF SIGNATURES ARE BEING PROPERLY VERIFIED.
            /*
            print('Debug: Checking signature for event id: ${eventData['id']}');
            print('Debug: Event id verification: ${event_id == eventData['id']}');
            print('Debug: Signature verification: $isSignatureValid');
            print ("----------------------- $isSignatureValid ");

             */

            if (isSignatureValid) {
              Map<String, String> stringData = {
                'id': eventData['id'].toString(),
                'pubkey': eventData['pubkey'].toString(),
                'created_at': eventData['created_at'].toString(),
                'kind': eventData['kind'].toString(),
                'tags': jsonEncode(eventData['tags']),
                'content': eventData['content'].toString(),
                'sig': eventData['sig'].toString(),
              };
              processedData.add(stringData);
            }
          }
        }
      }
    }

    return processedData;
  }


} //  END OF CLASS


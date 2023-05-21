import 'package:flutter/material.dart';
import 'package:emoji_data/emoji_data.dart';
import 'og_hive_interface.dart';
import 'dart:convert';
import 'dart:math';


// Various utility and helper functions.
class OG_util {

  static String getIdFromEvent(String event) {

    String id = "";
    if (event == null || event == "") {
      return "";
    }

    try {
      List<dynamic> eventDecoded = jsonDecode(event);
      Map<String, dynamic> eventJSON_Map = eventDecoded[1];
      id = eventJSON_Map['id'];
    } catch (e) {
      print(e);
    }
    return id;
  }


  static String getEtagValueFromRequest(String request) {
    // Decode the JSON string
    if (request == null || request == "") {
      return "";
    }

    List<dynamic> decodedRequest = jsonDecode(request);

    // Check if the request has the required fields
    if (decodedRequest.length == 3 &&
        decodedRequest[2] is Map<String, dynamic> &&
        decodedRequest[2].containsKey("#e")) {
      List<dynamic>? etagList = decodedRequest[2]["#e"];

      // Check if the ETag list has at least one value
      if (etagList != null && etagList.isNotEmpty) {
        // Return the first ETag value
        return etagList[0];
      }
    }

    // Return an empty string if no ETag value is found
    return "";
  }

  static int getMostRecentTimeBeforeEOSE(List<dynamic> fetchedData) {
    int mostRecentTime = 0;
    int createdAt = 0;

    /*
    This is meant to be universal, not just initial request.
    Thus, we cant rely on an actual EOSE, so dont bother looking.
    Instead treat our own empty buffer (usually after 3 seconds) as empty.
    Function name is bit of a misnomer but that's ok for now. Point
    is we are getting most recent message in the last request or buffer
    push so we can keep the cache up to date

     */

    for (String eventString in fetchedData) {
      List<dynamic> eventData = jsonDecode(eventString);
      if (eventData.length < 3) {
        continue;
      }

      // handles "OK" messages.
      if (eventData[2] is bool) {
        continue;
      }

      Map<String, dynamic> eventContent = eventData[2];
      if (eventContent.containsKey("created_at")) {
        createdAt = eventContent["created_at"];
        mostRecentTime = max(mostRecentTime, createdAt);
      }
    }

    return mostRecentTime;
  }


  static bool isKind42Request(String jsonString) {
    // Parse the input string as a JSON array
    List<dynamic> jsonArray = jsonDecode(jsonString);

    // Ensure the third element in the array is an object
    if (jsonArray.length >= 3 && jsonArray[2] is Map<String, dynamic>) {
      // Check if the 'kinds' property is an array containing exactly the value 42
      if (jsonArray[2]['kinds'] is List<dynamic> &&
          jsonArray[2]['kinds'].length == 1 &&
          jsonArray[2]['kinds'][0] == 42) {
        return true;
      }
    }

    return false;
  }


  static String changeLimitFilterOnQuery(String jsonString, int limit) {
    // Parse the input string as a JSON array
    List<dynamic> jsonArray = jsonDecode(jsonString);

    // Ensure the third element in the array is an object
    if (jsonArray.length >= 3 && jsonArray[2] is Map<String, dynamic>) {
      // Add the provided foo1value and foo2value to the object
      jsonArray[2]['limit'] = limit;
      // Convert the modified JSON array back to a string
      return jsonEncode(jsonArray);
    } else {
      throw ArgumentError('The input JSON string does not have the expected structure');
    }
  }


  static String addTimeStampFiltersToQuery(String jsonString, {int since=0, int until=0}) {
    // Parse the input string as a JSON array
    List<dynamic> jsonArray = jsonDecode(jsonString);

    // Ensure the third element in the array is an object
    if (jsonArray.length >= 3 && jsonArray[2] is Map<String, dynamic>) {
      // Add the provided foo1value and foo2value to the object
      if (since != 0) {
        jsonArray[2]['since'] = since;
      }
      if (until !=0 ) {
        jsonArray[2]['until'] = until;
      }
      // Convert the modified JSON array back to a string
      return jsonEncode(jsonArray);
    } else {
      throw ArgumentError('The input JSON string does not have the expected structure');
    }
  }


  static List<String> getAllEmojis() {
    List<String> allEmojis = Emoji.smileys + Emoji.symbols + Emoji.foodDrink + Emoji.animalsNature + Emoji.travelPlaces + Emoji.objects + Emoji.activityAndSports + Emoji.clothingAndAccessories + Emoji.flags + Emoji.gesturesAndBodyParts + Emoji.peopleAndFantasy;
    return allEmojis;
  }

 static List<String> getAllEmojiRunes()  {
    final allEmojis = getAllEmojis();
    List<String> allEmojiRunes = [];
    for (String emoji in allEmojis) {
      allEmojiRunes.add(emoji);
    }

    return allEmojiRunes;
  }

  static String cleanInvalidUtf16(String input) {
    StringBuffer buffer = StringBuffer();
    int? prevCodeUnit;
    for (int codeUnit in input.codeUnits) {
      if ((codeUnit & 0xFC00) == 0xD800) {
        // High surrogate
        prevCodeUnit = codeUnit;
      } else if ((codeUnit & 0xFC00) == 0xDC00) {
        // Low surrogate
        if (prevCodeUnit != null) {
          buffer.writeCharCode(prevCodeUnit);
          buffer.writeCharCode(codeUnit);
          prevCodeUnit = null;
        }
      } else {
        if (prevCodeUnit != null) {
          prevCodeUnit = null;
        }
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }


  static  List<TextSpan> createTextSpans(String input, {TextStyle? textStyle, TextStyle? emojiStyle}) {
    List<TextSpan> defaultSpans = [
      TextSpan(text: input, style: textStyle)
    ];

    try {
      List<TextSpan> spans = _processEmojiSpans(input, textStyle: textStyle, emojiStyle: emojiStyle);
      return spans;
    } catch (e) {
      print('Error processing emoji spans: $e');
      return defaultSpans;
    }
  }

  static List<TextSpan> _processEmojiSpans(String input, {TextStyle? textStyle, TextStyle? emojiStyle})  {
    input = cleanInvalidUtf16(input);
    List<TextSpan> spans = [];
    String currentText = '';
    // Define a list of emojis you want to check
    List<String> emojiRunes =  getAllEmojiRunes();
    for (int rune in input.runes) {
      String char = String.fromCharCode(rune);
      if (emojiRunes.contains(char)) {
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(text: currentText, style: textStyle));
          currentText = '';
        }
        spans.add(TextSpan(text: char, style: emojiStyle));
      } else {
        currentText += char;
      }
    }
    if (currentText.isNotEmpty) {
      spans.add(TextSpan(text: currentText, style: textStyle));
    }
    return spans;
  }




  static Color getChatNameColorFromNumber(int chatColorNumber) {

    switch (chatColorNumber) {
      case 1:
        return Colors.blue;
        break;
      case 2:
        return Colors.orange;
        break;
      case 3:
        return Colors.purple;
        break;
      case 4:
        return Colors.green;
        break;
      case 5:
        return Colors.redAccent;
        break;
      case 6:
        return Colors.grey;
        break;
      default:
        return Colors.blue;
    }

  }

  static Future<String> getTimeZoneFromConfig()  async {


    String timeZone = "";
    Map<String, dynamic> configMap = await OG_HiveInterface.getData_ConfigSettings();
    timeZone = configMap['timezone'] ?? '';
    if (timeZone == null) {
      timeZone = "GMT-1";
    }
    else if (timeZone == "") {
      timeZone = "GMT-1";
    }
     return timeZone;
  }

 static int parseTimeZoneOffset(String timezone) {
    // Extract the timezone offset from the string
    final RegExp timeZoneRegExp = RegExp(r'GMT([+-]\d+)');
    final Match? match = timeZoneRegExp.firstMatch(timezone);
    if (match != null && match.groupCount >= 1) {
      final int offsetHours = int.parse(match.group(1)!);
      return offsetHours * 60 * 60 * 1000; // Convert offsetHours to milliseconds
    }
    return 0;
  }

static bool areListsOfMapsEqual(List<Map<String, String>> list1, List<Map<String, String>> list2) {
  if (list1.length != list2.length) {
    return false;
  }

  for (int i = 0; i < list1.length; i++) {
    if (list1[i].length != list2[i].length) {
      return false;
    }
    for (final key in list1[i].keys) {
      if (list1[i][key] != list2[i][key]) {
        return false;
      }
    }
  }
  return true;
}

}

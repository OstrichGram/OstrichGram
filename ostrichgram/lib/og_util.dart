import 'package:flutter/material.dart';
import 'package:emoji_data/emoji_data.dart';
import 'og_hive_interface.dart';

class OG_util {

  // Various utility and helper funcions.

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

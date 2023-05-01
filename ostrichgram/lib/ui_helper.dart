import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'nostr_core.dart';
import 'og_hive_interface.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'multiavatar2.dart';
import 'svg_wrapper.dart';
import 'my_paint.dart';
import 'chat_bubbles-1.4.1/chat_bubbles.dart';
import 'og_util.dart';
import 'global_config.dart';

/*
This class is mostly a static collection of functions that are called directly from the main.dart and
a few other places to build widget collections.
 */

class ui_helper {
  static Future<void> init() async {
  }

 /* This function generates a "drawable root", which is a primitive used for SVG graphics.
 We are using the multiavatar open source library to generate avatars.  Here is it customized
 to override the theme (avatar style) so that the user can specify for example that Bob is
 to be a robot avatar. We also have a black and white option so non-contacts in the group
 chats will be less colorful, although we do add some color so they aren't purely black and white,
 but the parameter is still called blackandWhite.

  */
  static Future<DrawableRoot> generateAvatar(String imageSeedValue,
      {String? themeOverride, bool blackAndWhite = false}) async {

    if (themeOverride != null) {
      if (themeOverride.length == 1) {
        themeOverride = "0" + themeOverride;
      }
    }
    bool makeBW = false;
    if (blackAndWhite != null) {
      if (blackAndWhite == true) {
        makeBW = true;
      }
    }

    String svgCode = multiavatar(
        imageSeedValue, themeOverride: themeOverride, makeBW: makeBW);
    DrawableRoot svgRoot = await SvgWrapper(svgCode).generateLogoSync();
    return svgRoot;
  }

  // This creates a "one time" bubble for certain cases where we want to dispaly an error, warning, or just a message.
  static List<Widget> errorBubble(String msg1, String msg2, {Color msgColor = Colors.red}) {
    Widget errorWidget = Container(
        child: Align(
        alignment: Alignment.center,
        child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 500,
              constraints: BoxConstraints(maxWidth: 500),
              // Add this line to set max width
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                        text: msg1,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: msgColor,
                            decoration: TextDecoration.none)),
                    TextSpan(
                        text: '\n\n',
                        style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 12,
                            color: Colors.black,
                            decoration: TextDecoration.none)),
                    TextSpan(
                        text: msg2,
                        style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                            color: Colors.black,
                            decoration: TextDecoration.none)),
                    TextSpan(
                        text: '\n\n',
                        style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 12,
                            color: Colors.black,
                            decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
        ),
    );
    return [errorWidget];
  }

 // These are the text rows used for the reply preview.
  /*
    Didn't implement a replyDisplayNameColor for now because the color comes from the userdetails array which is built
    during the getallchatitems process. not worth the complication to re use that code in this context , so just use black?
     */

  static Widget getReplyWidgetItems(String replyMessageText, String replyDisplayName, Color replyDisplayNameColor) {
    return SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    replyDisplayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    replyMessageText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // This function builds a chat bubble for a relay room.
  static Widget buildChatBubbleRelay(BuildContext context, onMainCallback,
      String name, String about, String group_id,
      {Map<String, dynamic>? aux_data}) {

    String createdAt = aux_data?['created_at']?.toString() ?? '';
    if (createdAt.isNotEmpty) {
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(
          int.parse(createdAt) * 1000);
      createdAt = DateFormat.yMMMMd().add_jm().format(date);
    }

    String messageText = 'Name: $name\n\n$about\n\nCreated at: $createdAt';

    void _handleLeftClick_kind40() {
      onMainCallback('kind40_left_click', group_id, aux_data: aux_data);
    }

    void _handleRightClick_kind40_MenuOption1() {
      onMainCallback(
          'kind40_right_click_add_group', group_id, aux_data: aux_data);
    }

    void _handleRightClick_kind40_MenuOption2() {
      onMainCallback(
          'kind40_right_click_copy_groupID', group_id, aux_data: aux_data);
    }

    void _showRightClickMenu_kind40(BuildContext context,
        Offset globalPosition) {
      final items = <PopupMenuEntry>[
        PopupMenuItem(
          value: 1,
          child: Text('Add Group'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Copy Group ID'),
        ),
      ];

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
            globalPosition.dx, globalPosition.dy, globalPosition.dx,
            globalPosition.dy),
        items: items,
      ).then((value) {
        if (value == 1) {
          _handleRightClick_kind40_MenuOption1();
        } else if (value == 2) {
          _handleRightClick_kind40_MenuOption2();
        }
      });
    }

    // MAIN PART OF FUNCTION THAT BUILDS THE RELAY BUBBLE:

    return GestureDetector(
      onTap: _handleLeftClick_kind40,
      onSecondaryTapDown: (details) {
        _showRightClickMenu_kind40(context, details.globalPosition);
      },
      child: Container(
        child: Stack(
          children: [
            Align(
              // ...
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                constraints: BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Color(0xFF9D58FF), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: <TextSpan>[
                          TextSpan(
                            text: name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          TextSpan(
                            text: '\n\n',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          TextSpan(
                            text: about,
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          TextSpan(
                            text: '\n\nCreated at: $createdAt',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Image.asset('assets/images/GROUP-25.png', width: 25, height: 25),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    //end gesture detector

  }  // END OF BUILDCHATBUBBLE RELAY.


  // This function extracts the "e-tag" value from the auxilliary data for an event.
  static String get_Etag_Value(Map<String, dynamic>? aux_data) {
    if (aux_data == null) {
      return '';
    }

    String? tagsString = aux_data['tags'];
    if (tagsString == null) {
      return '';
    }

    List<dynamic> tagsList = jsonDecode(tagsString);
    for (List<dynamic> tag in tagsList) {
      if (tag.isNotEmpty && tag[0] == "e") {
        return tag[1].toString();
      }
    }

    return '';
  }

  // This function generates the avatar for contact creation, which are previews.
  static Future<Widget> getAvatarSvgforContactCreate(int index) async {

    String seedString = "";

    String indexString = index.toString();
    if (indexString.length < 2) {
      indexString = "0" + indexString;
    }

    Random random = new Random();
    int randomNumber = random.nextInt(9999);
    seedString = randomNumber.toString();

    DrawableRoot svgRoot = await generateAvatar(
        seedString, themeOverride: indexString);

    return CustomPaint(
      painter: MyPainter60(svgRoot, Size(60, 60)),
      size: Size(60, 60),
    );
  }

  // This function builds the image for the person next to their chat message in the main window, either a friend, other person, or user himself.
  static Widget buildChatUserImage(BuildContext context,
      Function onMainCallback, Map<String, dynamic> auxData,
      {bool chatRowIsFriend = false, String avatar_style = "default", bool chatRowIsMe = false, customOstrich = "1"}) {
    String customOstrichIcon = '';
    if (chatRowIsMe) {
      customOstrichIcon = "assets/images/OS-" + customOstrich + ".png";
    }
    String pubkey = auxData['pubkey'];
    return GestureDetector(
      onTap: () {
        onMainCallback('user_icon_tap', 'some_value');
      },
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(details.globalPosition.dx,
              details.globalPosition.dy, details.globalPosition.dx,
              details.globalPosition.dy),
          items: [
            PopupMenuItem(
              value: 1,
              child: Text('Copy User npub'),
            ),
            PopupMenuItem(
              value: 2,
              child: Text('Add Contact'),
            ),
          ],
        ).then((value) {
          if (value == 1) {
            onMainCallback('right_click_user_icon_copyID', pubkey);
          } else if (value == 2) {
            onMainCallback('right_click_user_icon_addFriend', pubkey);
          }
        });
      },
      child: FutureBuilder(
        future: chatRowIsMe ? null : generateAvatar(
            pubkey, blackAndWhite: !chatRowIsFriend,
            themeOverride: avatar_style),
        builder: (BuildContext context, AsyncSnapshot<DrawableRoot?> snapshot) {
          if (chatRowIsMe) {
            return Image.asset(customOstrichIcon,
              width: 60,
              height: 60,
            );
          } else if (snapshot.connectionState == ConnectionState.done) {
            return CustomPaint(
              painter: MyPainter60(snapshot.data!, Size(60, 60)),
              size: Size(60, 60),
            );
          } else {
            return CircularProgressIndicator();
          }
        },
      ),
    );
  }

  // This function builds the entire row , including both the chat user image and the chat bubble. This is for group chat.
  static Future<Widget> buildChatBubbleRowGroup(BuildContext context,
      Function onMainCallback, String message_text,
      Map<String, dynamic> aux_data, String displayName, bool chatBubbleIsMe,
      Color displayNameColor,
      {String replyDisplayName = "", String replySnippet = "", Color replyDisplayNameColor = Colors
          .blue}) async {

    //  There is possibly some rendundancy with logic and varibles here as certain things are now passed in like chatBubbleIsMe.
    String some_chat_pubkey = "";
    String avatar_style = "default";
    some_chat_pubkey = aux_data['pubkey'];
    Map<String, dynamic> friendMap = await OG_HiveInterface
        .getData_FriendMapFromPubkey(some_chat_pubkey);
    bool chatRowIsFriend = false;
    bool chatRowIsMe = false;
    String user_pubkey = "";
    Map<String, String> chosenAliasData = await OG_HiveInterface
        .getData_Chosen_Alias_Map();
    String alias = chosenAliasData?['alias'] ?? '';
    user_pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);
    String? customOstrich = "1";
    if (some_chat_pubkey == user_pubkey) {
      chatRowIsMe = true;

      // Each alias has a "custom ostrich color" we should fetch and get the right image for.
      Map<String, dynamic> aliasMap2 = await OG_HiveInterface
          .getData_AliasMapFromName(alias);
      customOstrich = aliasMap2['customOstrich'] ?? '';
      if (customOstrich == null) {
        customOstrich = "1";
      }
      else if (customOstrich == "") {
        customOstrich = "1";
      }
    }
    if (friendMap.isEmpty) {
      chatRowIsFriend = false;
    } else {
      chatRowIsFriend = true;
      avatar_style = friendMap['avatar_style'];
    }

    String timeZone = "";
    timeZone= await OG_util.getTimeZoneFromConfig();


    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 20.0), // Add bottom and left padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min, // Add mainAxisSize property to Row
        children: [
          buildChatUserImage(context, onMainCallback, aux_data,
              chatRowIsFriend: chatRowIsFriend,
              avatar_style: avatar_style,
              chatRowIsMe: chatRowIsMe,
              customOstrich: customOstrich),
          SizedBox(width: 20),
          Flexible( // Replace Expanded with Flexible
            child: buildChatBubbleGroup(
                context, onMainCallback, message_text, aux_data, timeZone,
                displayName: displayName,
                chatBubbleIsMe: chatRowIsMe,
                displayNameColor: displayNameColor,
                replyDisplayName: replyDisplayName,
                replySnippet: replySnippet,
                replyDisplayNameColor: replyDisplayNameColor),
          ),
        ],
      ),
    );

  }


  // This builds the entire row for a chat, (user image + chat bubble), but for a nip 04 DM
  static Future<Widget> buildChatBubbleRowFriend(BuildContext context,
      Function onMainCallback, String message_text,
      Map<String, dynamic> aux_data, bool senderIsMe, String timeString) async {

    String some_chat_pubkey = aux_data['pubkey'];
    Map<String, dynamic> friendMap = await OG_HiveInterface.getData_FriendMapFromPubkey(some_chat_pubkey);
    bool chatRowIsFriend = false;
    bool chatRowIsMe = false;
    String user_pubkey = "";
    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String alias = chosenAliasData?['alias'] ?? '';
    String avatar_style = "default";
    String? customOstrich = "1";

    Map<String, dynamic> aliasMap2 = await OG_HiveInterface.getData_AliasMapFromName(alias);
    user_pubkey = aliasMap2['pubkey'];
    customOstrich = aliasMap2['customOstrich'] ?? '';

    if (some_chat_pubkey == user_pubkey) {
      chatRowIsMe = true;

      if (customOstrich == null) {
        customOstrich = "1";
      }
      else if (customOstrich == "") {
        customOstrich = "1";
      }
    }
    if (friendMap.isEmpty) {
      chatRowIsFriend = false;
    } else {
      chatRowIsFriend = true;
      avatar_style = friendMap['avatar_style'];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          buildChatUserImage(context, onMainCallback, aux_data,
              chatRowIsFriend: chatRowIsFriend,
              avatar_style: avatar_style,
              chatRowIsMe: chatRowIsMe,
              customOstrich: customOstrich ),
          SizedBox(width: 20),
          buildChatBubbleFriend(
              context, onMainCallback, message_text, aux_data,senderIsMe, timeString),
        ],
      ),
    );
  }

  // This function builds the chat bubble for a DM.
  static Widget buildChatBubbleFriend(BuildContext context,
      Function onMainCallback, String message_text,
      Map<String, dynamic> aux_data, bool senderIsMe, String timeString) {

    Color chatBubbleColor = Colors.white;

    // Background color for user is green, others are white.
    if (senderIsMe) {
      Color specialGreen = Color(0xFFE6FDC8);
      chatBubbleColor = specialGreen;
    }

    // Get the little time stamp widget string
    String newline = "\n";
    String timeTextWidgetString = newline + timeString;

    return GestureDetector(

      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery
              .of(context)
              .size
              .width * 0.7, 500),
        ),
        // Use the chat bubble library to give a cool shape to the chatbubble
        child: BubbleSpecialFour(
          my_children: createChatBubbleTextRows(
              message_text, timeTextWidgetString, "", Colors.black,
              senderIsMe),
          isSender: false,
          color: chatBubbleColor,
          tail: true,
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // This builds the chat bubble widget for the group chat.
  static Widget buildChatBubbleGroup(BuildContext context,
      Function onMainCallback, String message_text,
      Map<String, dynamic> aux_data, String timezone,
      {String displayName = "", bool chatBubbleIsMe = false, Color displayNameColor = Colors
          .blue, String replyDisplayName = "", String replySnippet = "", Color replyDisplayNameColor = Colors
          .blue }) {

    GlobalConfig globalConfig = GlobalConfig();
    int max_group_message_chars = globalConfig.max_group_message_chars;

    if (message_text.length > max_group_message_chars) {
       message_text = message_text.substring(0, max_group_message_chars);
    }

    String eTagValue = get_Etag_Value(aux_data);
    Color chatBubbleColor = Colors.white;
    if (chatBubbleIsMe) {
      Color specialGreen = Color(0xFFE6FDC8);
      chatBubbleColor = specialGreen;
    }

    final String createdAtString = aux_data['created_at'];
    final String eventID = aux_data['id'];
    final int timeZoneOffsetMillis = OG_util.parseTimeZoneOffset(timezone);
    final DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
      (int.parse(createdAtString.trim()) * 1000) + timeZoneOffsetMillis,
    ).toUtc();

    final DateFormat timeFormat = DateFormat('h:mm a');
    final String timeString = timeFormat.format(createdAt);
    String newline = "\n";
    String timeTextWidgetString = newline + timeString;

    return GestureDetector(
      onTap: () {
        onMainCallback(
            'left_click_group_chat_msg', aux_data['id'], aux_data: aux_data);
      },
      onSecondaryTapDown: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
              details.globalPosition.dx, details.globalPosition.dy,
              details.globalPosition.dx, details.globalPosition.dy),
          items: [
            PopupMenuItem(
              value: 1,
              child: Text('Reply'),
            ),

          ],
        ).then((value) {
          if (value == 1) {
            onMainCallback('right_click_group_chat_msg_reply', aux_data['id'],
                aux_data: aux_data);
          } else if (value == 2) {
            onMainCallback('right_click_group_chat_copy_text', aux_data['id'],
                aux_data: aux_data);
          }
        });
      },


      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(MediaQuery
              .of(context)
              .size
              .width * 0.7, 500),
        ),
        child: BubbleSpecialFour(
          my_children: createChatBubbleTextRows(
              message_text, timeTextWidgetString, displayName, displayNameColor,
              chatBubbleIsMe, replyDisplayName: replyDisplayName,
              replySnippet: replySnippet,
              replyDisplayNameColor: replyDisplayNameColor),
          isSender: false, // This should be false, it is a property of chat_bubble library.  This puts the chat on left side instead of right.
          color: chatBubbleColor,
          tail: true,
          textStyle: TextStyle(
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // This function builds the text rows for the bubbles.
    static List<Widget> createChatBubbleTextRows(String message_text, String timeTextWidgetString, String displayName, Color displayNameColor, bool chatBubbleIsMe, { String replyDisplayName = "", String replySnippet="", Color replyDisplayNameColor = Colors.blue}) {

    /*

    This function does custom parsing of text into emoji and non-emoji character spans so that we an alternate fonts,
    as there didn't seem to be a single font or combination of fallback fonts that handled it well.  Fallback fonts
    created large gaps instead of ordinary spaces. Although interestingly, the fallback font works on the input
    bar itself (and parsing it there was problematic).
     */


    if (replyDisplayName !="") {
      replyDisplayName="  ┃" + replyDisplayName;
    }

    if (replySnippet !="") {
      replySnippet="  ┃" + replySnippet+"\n";
    }

      TextStyle normalTextStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Roboto', height: 1.2);
      TextStyle emojiStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Noto Color Emoji');
      List<TextSpan> textSpans = [];

      List<Widget> textRows = [];


    // IF THIS IS A REPLY BUBBLE...
    if (replyDisplayName != "" && replySnippet != "") {

      normalTextStyle = TextStyle(color: replyDisplayNameColor, fontSize: 16, fontFamily: 'Roboto', height: 1.5);
      emojiStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Noto Color Emoji');
      textSpans = OG_util.createTextSpans(replyDisplayName, textStyle: normalTextStyle, emojiStyle: emojiStyle);

      textRows.add(Text.rich(
        TextSpan(
          children: textSpans,
        ),
      ));



      normalTextStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Roboto', height: 1.2);
      emojiStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Noto Color Emoji');
      textSpans = OG_util.createTextSpans(replySnippet, textStyle: normalTextStyle, emojiStyle: emojiStyle);

      textRows.add(Text.rich(
        TextSpan(
          children: textSpans,
        ),
      ));

    }


    if (displayName != null) {
      if (displayName.isNotEmpty) {
        if (displayName.length > 27) {
          displayName = displayName.substring(0,25) + "...";
        }
      }
    }

    if (displayName != null && displayName.isNotEmpty && !chatBubbleIsMe) {

      normalTextStyle = TextStyle(color: displayNameColor, fontSize: 16, fontFamily: 'Roboto');
      emojiStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Noto Color Emoji');
       textSpans = OG_util.createTextSpans(displayName, textStyle: normalTextStyle, emojiStyle: emojiStyle);

      textRows.add(Text.rich(
        TextSpan(
          children: textSpans,
        ),
      ));

    }


//  MAIN TEXT MESSAGE:

      normalTextStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Roboto');
      emojiStyle = TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Noto Color Emoji');
      textSpans = OG_util.createTextSpans(message_text, textStyle: normalTextStyle, emojiStyle: emojiStyle);
      textRows.add(Text.rich(
        TextSpan(
          children: textSpans,
        ),
      ));



    textRows.add(
      Text(
        timeTextWidgetString,
        style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontFamily: 'Roboto'),
      ));

    return textRows;
  }



 // Get all the chat items for a friend room and return them to the widget tree
  static Future<List<Widget>> getAllChatItemsFriend(BuildContext context, Function onMainCallback, String friend_pubkey, List<Map<String, String>> rawData) async {
    //   Build Widgets

    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String chosenAliasName = chosenAliasData?['alias'] ?? '';
    String my_user_pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(chosenAliasName);
    String timezone = "";
    timezone= await OG_util.getTimeZoneFromConfig();
    List<Widget> widgets = [];

    for (var message in rawData) {
      try {
        String? id = message['id'];
        String? pubkey = message['pubkey'];
        String? encrypted_msg = "";
        if (message['content'] != null) {
          encrypted_msg = message['content'];
        }
        String? decrypted_msg = "";

        try {
          decrypted_msg = await nostr_core.decipher_kind04_message(friend_pubkey, encrypted_msg ?? '');
        } catch (e) {
          print('Something went wrong deciphering nip04 message $e');
          return [];
        }

        if (decrypted_msg == null) {
          decrypted_msg = "";
        }
        String content = decrypted_msg;

        // Determine if the sender is the user
        bool senderIsMe = pubkey == my_user_pubkey;

        // Create timeString from message
        String createdAtString = message['created_at'] ?? '';
        int timeZoneOffsetMillis = OG_util.parseTimeZoneOffset(timezone);
        DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
          (int.parse(createdAtString.trim()) * 1000) + timeZoneOffsetMillis,
        ).toUtc();
        DateFormat timeFormat = DateFormat('h:mm a');
        String timeString = timeFormat.format(createdAt);

        // Build the row (image + message)
        if (id != null && content != null) {
          Widget chatitemrow =  await buildChatBubbleRowFriend(context, onMainCallback, content, message, senderIsMe, timeString);
          widgets.add(chatitemrow);
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    }

    return widgets;
  }


  // Get all Chat items for a group chat.
  static Future<List<Widget>> getAllChatItemsGroup(BuildContext context, Function onMainCallback, String group_id, List<Map<String, String>> rawData) async {

    // Determine current user
    Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
    String chosenAliasName = chosenAliasData?['alias'] ?? '';

    // Get user Pubkey
    String my_user_pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(chosenAliasName);

    // sort message by date
    rawData.sort((b, a) => int.parse(b['created_at']!).compareTo(int.parse(a['created_at']!)));

    //define colors
    Map<String, Map<String, dynamic>> userDetails = {};
    int colorCounter = 1;
    await for (var message in Stream.fromIterable(rawData)) {
      String? pubkey = message['pubkey'];
      if (pubkey != null && !userDetails.containsKey(pubkey)) {
        String displayName = await getDisplayName(pubkey); // Call the sub-function to get the display name
        bool isMe = await userIsMe(pubkey, my_user_pubkey); // Call the sub-function to check if the user is the app user

        userDetails[pubkey] = {
          'pubkey': pubkey, // Add the pubkey to the userDetails map
          'color': colorCounter,
          'displayName': displayName,
          'isMe': isMe,
        };

        // Rotate through 6 Ostrich colors.
        colorCounter = colorCounter + 1;
        if (colorCounter == 7) {
          colorCounter = 1;
        }
      }
    }

   // Put the whole event into the aux_data
    List<Widget> widgets = [];
    for (var message in rawData) {
      try {
        String? id = message['id'];
        String? content = message['content'];
        String? pubkey = message['pubkey'];
        Map<String, dynamic>? aux_data = jsonDecode(message['aux_data'] ?? '{}');
        if (id != null && content != null && pubkey != null && userDetails.containsKey(pubkey)) {

        // Set the strings based on the message
          String displayName = userDetails[pubkey]?['displayName'] as String;
          bool chatBubbleIsMe = userDetails[pubkey]?['isMe'] as bool;

          // Default to something even though we should have it
          int userColor = 1;

          if (userDetails != null) {
            var userMap = userDetails[pubkey];
            if (userMap != null) {
              userColor = userMap['color'];
            }
          }

          Color displayNameColor = OG_util.getChatNameColorFromNumber(userColor);

          //Deal with the tags of the events so we can do things with them like reply

          String eTagReply = "";
          String pTagReply = "";
          String? tagsString ="";

          if (message != null && message['tags'] != null) {
            tagsString  = message['tags'];
          }
          if (tagsString != "") {
            List<dynamic> mytags = jsonDecode(tagsString ?? "");

            for (var mytag in mytags) {
              if (mytag is List<dynamic> && mytag.length >= 2) {
                if (mytag[0] == "e") {
                  if (mytag.length >= 3 && mytag[2] == "reply") {
                    eTagReply = mytag[1];
                  }
                }
                if (mytag[0] == "p") {
                  pTagReply = mytag[1];
                }
              }
            }
          }

          String replyDisplayName = '';
          String replySnippet = '';
          Color replyDisplayNameColor = Colors.black;


          if (eTagReply.isNotEmpty) {
            for (var event in rawData) {
              if (event['id'] == eTagReply) {
                replySnippet = event['content']?.substring(0, min(30, event['content']!.length)) ?? '';
                break;
              }
            }
          }


          if (pTagReply.isNotEmpty && userDetails[pTagReply]?['isMe']) {
            replyDisplayName = "me";
            replyDisplayNameColor = Colors.black;
            }

          else if (pTagReply.isNotEmpty && userDetails.containsKey(pTagReply)) {
            replyDisplayName = userDetails[pTagReply]?['displayName'] as String;
            if (replyDisplayName.length > 27) {
              replyDisplayName = replyDisplayName.substring(0,25) + "...";
            }
            int replyUserColor = userDetails[pTagReply]?['color'] as int;
            replyDisplayNameColor = OG_util.getChatNameColorFromNumber(replyUserColor);
          }

          /*
          Basically this function does a lot of work to grab the e and p tags from the message, so we can
          then identify the person we are replying to and what the message was we're replying to.  The
          information has to be put into the bubble widgets so that when the user right clicks on
          them to reply , the information can sent via callback to the main processCallback to
          then build ui objects (reply preview) and nostr events (replies).  We build these
          three variables replyDisplayName, replyDisplayNameColor, and replySnippet, along with
          the other ones.

           */

          // Call to build the entire chatrow.
          Widget chatItemRow = await buildChatBubbleRowGroup(context, onMainCallback, content, message, displayName, chatBubbleIsMe, displayNameColor, replyDisplayName: replyDisplayName, replySnippet: replySnippet, replyDisplayNameColor: replyDisplayNameColor);
          widgets.add(chatItemRow);
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    }
    return widgets;
  }




  static Future<String> getDisplayName(String pubkey) async {
    // This should return the name of a friend if they are a contact,
    // but if not, then just the npub... of a stranger.

    String friend ="";
    Map <String,dynamic> friendMap = await OG_HiveInterface.getData_FriendMapFromPubkey(pubkey);
    if (friendMap != null) {
      if (friendMap['friend'] != null) {
        friend = friendMap['friend'];
      }
    }
    String retval ="";
    if (friend != "") {
      retval = friend;
    } else {
      retval = pubkey;

      String prefix = "npub";
      String friend_npub ="";
      try {
        friend_npub = nostr_core.hexToBech32(pubkey, prefix);
      } catch (e) {
        print ('problem converting friend key to npub in getDisplayName.');
      }
      retval = friend_npub;

    }
    return retval;
  }

  // Determines if person in a chat message is the user
  static bool userIsMe(String pubkey, String myPubkey) {
   if (pubkey==myPubkey) {
     return true;
   }
   else {
     return false;
   }
  }

  // Get all "chat items" for a relay, IOW lists of group chats.
  static Future<List<Widget>> getAllChatItemsRelay(BuildContext context, Function onMainCallback, String relay, List<Map<String, String>> rawData) async {

    // Generate widgets
    List<Widget> widgets = [];
    for (var message in rawData) {
      try {
        Map<String, dynamic> content = jsonDecode(message['content'] ?? '');
        String name = content['name'] ?? '';
        String about = content['about'] ?? '';
        String relayString = relay ?? '';
        String group_id =  (message['id'] ?? '')  + "," + relayString;
        message['group_name'] = name;
        widgets.add(buildChatBubbleRelay(context, onMainCallback, name, about, group_id, aux_data: message)); // Pass the entire message map as aux_data
      } catch (e) {
        print('Error processing message: $e');
      }
    }

    return widgets;
  }


// A primary function for fetching all the stuff on the left pane/panel.
  static List<Widget> getLeftPaneListItems(BuildContext context, Function onMainCallback, List<dynamic> relayListData, List<dynamic> groupListData, List<dynamic> friendsListData, int leftPaneSortStyle) {

    String randomString = '';
    Random random = Random();

    for (int i = 0; i < 10; i++) {
      int randomInt = random.nextInt(26) + 65; // generates a random integer between 65 and 90 (inclusive)
      String randomChar = String.fromCharCode(randomInt); // converts the integer to its corresponding character
      randomString += randomChar;
    }

    //Deprecated, here we could do a custom image seed and pass it to a deterministic image generator.
    // We instead use multiavatar, but if we ever want to reimplement it, this is still passed
    // , no need to remove it.
    Uint8List image_seed = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]); // Your seed


    // Build the list of widgets using the sorted combined list
    List<Widget> leftPaneWidgets = [
      buildSliderPanel(context),
    ];

    int sort_type = leftPaneSortStyle;
    // sort_type 0 means chronologically, sort_type 1 means alphabetically by category.

    if (sort_type == 0 ) {

      // Collate data from the three lists
      List<dynamic> combinedList = [];

      combinedList.addAll(relayListData.map((item) => {...item, "type": "relay", "left_panel_position": num.parse(item["left_panel_position"].toString())}));
      combinedList.addAll(groupListData.map((item) => {...item, "type": "group", "left_panel_position": num.parse(item["left_panel_position"].toString())}));
      combinedList.addAll(friendsListData.map((item) => {...item, "type": "friend", "left_panel_position": num.parse(item["left_panel_position"].toString())}));

      // Sort the combined list based on the left_panel_position key
      combinedList.sort((a, b) => a["left_panel_position"].compareTo(b["left_panel_position"]));
      combinedList = combinedList.reversed.toList();


      for (var item in combinedList) {
        if (item["type"] == "relay") {
          String uniqueId = item["relay"];
          leftPaneWidgets.add(buildListItemRelay(
              context, onMainCallback, item["relay"], image_seed, uniqueId));
          } else if (item["type"] == "group") {
          String uniqueId = item["group"];
          String itemContent = item["content"];

          dynamic decodedDynamic = jsonDecode(itemContent);
          String jsonString = decodedDynamic.toString();
          Map<String, dynamic> decodedJson = jsonDecode(jsonString);

          String name = decodedJson["name"] ?? '';
          String about = decodedJson["about"] ?? '';

          leftPaneWidgets.add(buildListItemGroup(
              context, onMainCallback, name, about, image_seed, uniqueId));
        } else if (item["type"] == "friend") {
          String uniqueId = item["pubkey"].toString();
          leftPaneWidgets.add(buildListItemFriend(
              context,
              onMainCallback,
              item["friend"],
              " ",   // Implement later some secondary text for a contact, maybe the last chat message snippet.
              " ", // Intended to be time of last message, not impmlemented yet . e.g. 7:00 PM
              item["avatar_style"],
              uniqueId));
        }
      }
    }


    // Fetch 3 separate lists and alphabetize each one
    if (sort_type == 1) {

      // Sort alphabetically by category
      relayListData.sort((a, b) => a["relay"].compareTo(b["relay"]));
      groupListData.sort((a, b) => a["group"].compareTo(b["group"]));
      friendsListData.sort((a, b) => a["friend"].compareTo(b["friend"]));

      // Add items to the leftPaneWidgets in the required order
      for (var item in relayListData) {
        String uniqueId = item["relay"];
        leftPaneWidgets.add(buildListItemRelay(
            context, onMainCallback, item["relay"], image_seed, uniqueId));
      }

      for (var item in groupListData) {
        String uniqueId = item["group"];
        String itemContent = item["content"];

        dynamic decodedDynamic = jsonDecode(itemContent);
        String jsonString = decodedDynamic.toString();
        Map<String, dynamic> decodedJson = jsonDecode(jsonString);

        String name = decodedJson["name"] ?? '';
        String about = decodedJson["about"] ?? '';

        leftPaneWidgets.add(buildListItemGroup(
            context, onMainCallback, name, about, image_seed, uniqueId));
      }

      for (var item in friendsListData) {
        String uniqueId = item["pubkey"].toString();
        leftPaneWidgets.add(buildListItemFriend(
            context,
            onMainCallback,
            item["friend"],
            "hello world",
            '7:00 PM',
            item["avatar_style"],
            uniqueId));
      }
    }
    return leftPaneWidgets;
  }

  //Show the right click context menu for a friend
  static void showContextMenuFriend(BuildContext context, Offset position, VoidCallback onOption1, VoidCallback onOption2, VoidCallback onOption3) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Copy npub'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Delete Contact'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text('Edit Contact'),
        ),
      ],
    ).then((value) {
      if (value == 1) {
        onOption1();
      } else if (value == 2) {
        onOption2();
      } else if (value == 3) {
        onOption3();
      }
    });
  }

  // Show the right click menu for a group
  static Future<void> showContextMenuGroup(BuildContext context, Offset position, VoidCallback onOption1, VoidCallback onOption2) async {
    final ThemeData customTheme = ThemeData(
      textTheme: TextTheme(
        subtitle1: TextStyle(color: Colors.black, fontSize: 16),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        color: Colors.white,
        enableFeedback: true,
        textStyle: TextStyle(color: Colors.black, fontSize: 16),
      ),
    );

    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;
    final RelativeRect positionInOverlay = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      overlay.size.width - position.dx,
      overlay.size.height - position.dy,
    );

    final value = await showMenu<int>(
      context: context,
      position: positionInOverlay,
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Remove Group'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Copy Group ID'),
        ),
      ],
    );

    if (value == 1) {
      onOption1();
    } else if (value == 2) {
      onOption2();
    }
  }

  // Right click menu for relay
  static void showContextMenuRelay(BuildContext context, Offset position, VoidCallback onOption1, VoidCallback onOption2) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Remove Relay'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Open'),
        ),
      ],
    ).then((value) {
      if (value == 1) {
        onOption1();
      } else if (value == 2) {
        onOption2();
      }
    });
  }

  // Left slider panel for more options like Aliases, settings, etc
  static Widget buildSliderPanel(BuildContext context) {
    return Builder(
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            Scaffold.of(context).openDrawer();
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.menu),
          ),
        );
      },
    );
  }

  // Build the widget set "list item" for the left panel.
  static Widget buildListItemRelay(BuildContext context, Function onMainCallback, String name, Uint8List seed, String unique_relay_id) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 15),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.blue, width: 1.0)),
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            showContextMenuRelay(
              context,
              details.globalPosition,
                  () => onMainCallback('right_click_remove_relay', unique_relay_id),
                  () => onMainCallback('right_click_open_relay', unique_relay_id),
            );
          },
          child: InkWell(
            onTap: () => onMainCallback('left_click_relay', unique_relay_id),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      child: Image.asset(
                        'assets/images/orb1-60.png',
                        fit: BoxFit.fill,
                        width: 60,
                        height: 60,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        height: 60, // Set the height equal to the row height
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),

                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CustomPaint(
                    size: Size(20, 20),
                    painter: TrianglePainterBlue(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// build left panel row for a friend
  static Widget buildListItemFriend(BuildContext context, Function onMainCallback, String name,  String message, String time, String avatar_style, String unique_friend_id) {
    Map<String, dynamic> auxData = {
      'friend_name': name,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 15),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.redAccent  , width: 1.0)),
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            showContextMenuFriend(
              context,
              details.globalPosition,
                  () => onMainCallback('right_click_copy_friendID', unique_friend_id),
                  () => onMainCallback('right_click_delete_friend', unique_friend_id),
                  () => onMainCallback('right_click_edit_friend', unique_friend_id),
            );
          },
          child: Stack(
            children: [
              InkWell(
                onTap: () => onMainCallback('left_click_friend', unique_friend_id, aux_data: auxData),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder(
                      future: generateAvatar(unique_friend_id, themeOverride: avatar_style),
                      builder: (BuildContext context, AsyncSnapshot<DrawableRoot?> snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Container(
                            width: 60,
                            height: 60,
                            child: CustomPaint(
                              painter: MyPainter60(snapshot.data!, Size(60, 60)),
                              size: Size(60, 60),
                            ),
                          );
                        } else {
                          return CircularProgressIndicator();
                        }
                      },
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                          Text(
                            message,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),

                        ],
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(20, 20),
                  painter: TrianglePainterRedAccent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



// build left panel row for a group
  static Widget buildListItemGroup(BuildContext context, Function onMainCallback, String name, String message, Uint8List seed, String unique_group_id) {
    Map<String, dynamic> auxData = {
      'group_name': name,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 15),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.purple, width: 1.0)),
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            showContextMenuGroup(
              context,
              details.globalPosition,
                  () => onMainCallback('right_click_remove_group', unique_group_id),
                  () => onMainCallback('right_click_copy_group_id', unique_group_id),
            );
          },
          child: Stack(
            children: [
              InkWell(
                onTap: () async {
                  await onMainCallback('left_click_left_panel_group', unique_group_id, aux_data: auxData);

                },


                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      child: Image.asset(
                        'assets/images/GROUP3.png',
                        fit: BoxFit.fill,
                        width: 60,
                        height: 60,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Container(
                        height: 60, // Set the height equal to the row height
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                message,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CustomPaint(
                  size: Size(20, 20),
                  painter: TrianglePainterPurple(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} //END CLASS UI HELPER

// Paint the triangle decoration for the left panel row
class TrianglePainterPurple extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, size.height * 1.1, size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// Paint the left panel decoration
class TrianglePainterBlue extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, size.height * 1.1, size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// left panel decoration
class TrianglePainterGreen extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, size.height * 1.1, size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// left panel decoration
class TrianglePainterRedAccent extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, size.height * 1.1, size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// Deprecated functions to generate a random image
Uint8List generateRandomImage({required int width, required int height}) {
  final random = Random();
  final Uint8List imageBytes = Uint8List(width * height * 4);

  for (int i = 0; i < imageBytes.length; i += 4) {
    final int color = random.nextInt(0xFFFFFFFF);
    imageBytes[i] = color >> 24 & 0xFF;
    imageBytes[i + 1] = color >> 16 & 0xFF;
    imageBytes[i + 2] = color >> 8 & 0xFF;
    imageBytes[i + 3] = color & 0xFF;
  }

  return imageBytes;
}


Future<Uint8List> generateRandomImage4(Uint8List seed, {required int width, required int height, bool blackAndWhite = false}) async {
  final rand = Random(_createImageSeed(seed));

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      int r = rand.nextInt(256);
      int g = blackAndWhite ? r : rand.nextInt(256);
      int b = blackAndWhite ? r : rand.nextInt(256);
      final color = Color.fromARGB(255, r, g, b);
      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
    }
  }

  final ui.Picture picture = recorder.endRecording();
  final ui.Image img = await picture.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  return byteData!.buffer.asUint8List();
}

int _createImageSeed(Uint8List bytes) {
  int seed = 0;
  for (int i = 0; i < bytes.length; i++) {
    seed = 31 * seed + bytes[i];
  }
  return seed;
}
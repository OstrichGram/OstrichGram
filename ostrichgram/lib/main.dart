import 'dart:math';
import 'package:flutter/material.dart';
import 'ui_helper.dart';
import 'package:window_size/window_size.dart';
import 'alias_screen.dart';
import 'og_hive_interface.dart';
import 'content_manager.dart';
import 'nostr_core.dart';
import 'web_socket_manager_multi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'my_paint.dart';
import 'top_container.dart';
import 'dart:convert';
import 'right_panel.dart';
import 'dart:async';
import 'render.dart';
import 'og_util.dart';
import 'global_config.dart';
import 'settings_screen.dart';
import 'input_bar_container.dart';
import 'og_emoji_picker.dart';
import 'about_screen.dart';
import 'package:flutter/foundation.dart';

/*

Main.dart is the main file for the application, and SplitScreenState is the main class that holds a split-screen
window.  In general, the app will build a list of left panel widgets that includes contacts (friends), groups,
and relays.  It runs a loop on a 3 second counter in _fetchDataFromWebSocketBuffer and updates the right panel based on the websocket events
combined with the database cache.  The main.dart also handles a number of callback events for other things
that happen in other parts of the application.  main.dart also calls to other classes like top container,
right panel, and input bar to create other parts of the app.
 */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setWindowMinSize(Size(700, 700));
  final ogHiveInterface = OG_HiveInterface();  // must instantiate even though we do nothing with the variable.
  final ContentManager contentManager = ContentManager();
  contentManager.start();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => SplitScreen(),
      },
    );
  }
}

class SplitScreen extends StatefulWidget {
  const SplitScreen({Key? key}) : super(key: key);

  @override
  SplitScreenState createState() => SplitScreenState();
}

// This class SplitScreenState is the "main" (main window) for most intents and purposes
class SplitScreenState extends State<SplitScreen> {
  double _leftSectionWidth = 0.2;
  double _dragStartPosition = 0.0;
  bool _dragging = false;
  final TextEditingController textEditingController = TextEditingController();
  List<Widget> _cachedRowItems = [];
  bool _shouldUpdateRowCache = true;
  String _rightPanelEventType = "";
  String _rightPanelUniqueRowId = "";
  bool showReplyWidget = false;
  bool _emojiPickerVisible = false;
  OverlayEntry? _emojiPickerOverlay;
  bool _dataReady = false;
  final ScrollController _scrollController = ScrollController();
  final WebSocketManagerMulti websocketmanagermulti = WebSocketManagerMulti();
  String _mainWebSocketURI = "";
  String _roomType = ""; // Values: "relay" "group" "friend" "fat_group"
  String _rightPanelRoomName = "";

  String get roomType => _roomType;

  String get rightPanelRoomName => _rightPanelRoomName;

  String get rightPanelUniqueRowId => _rightPanelUniqueRowId;
  late List<Map<String, String>> _cachedWidgetData;

  // Create a ValueNotifier with the test widgets list
  late ValueNotifier<List<Widget>> _RightPanelNotifier;
  GlobalKey<InputBarState> _inputBarKey = GlobalKey<InputBarState>();
  String? _eTagReply;
  String? _pTagReply;
  String? get eTagReply => _eTagReply;
  set eTagReply(String? value) => _eTagReply = value;
  String? get pTagReply => _pTagReply;
  set pTagReply(String? value) => _pTagReply = value;
  bool _oneTimeRepaintRightPanel = false; // this allows a forced repaint even when the message data didnt change (user added a contact, etc)
  int _leftPaneSortStyle = 0;
  ValueNotifier<bool> shouldRightPanelRequestFocus = ValueNotifier(true);
  String replyMessageText = "";
  String replyDisplayName = "";
  Color replyDisplayNameColor = Colors.blue;
  String _wallPaperString = 'assets/images/wallpapers/BLUE.png';
  String get wallPaperString => _wallPaperString;

  // This is for making sure the reply widget and emoji picker play nice together.
  ValueNotifier<bool> isEmojiPickerActive = ValueNotifier(false);

  // For the animation on top if checking signatures takes a while etc
  ValueNotifier<bool> processingWebSocketInfo = ValueNotifier(false);

  /* Keep track of the subscription IDs so we can double check the buffer against the request.  This can prevent the wrong messages from showing up in the wrong room if the user clicks around too fast while the buffer is trying to update.
  We need two of these for DMs (one for user messages, one for friend's messages.  We also need multiple for multi relay chat (fatgroup), so use a list of strings.
   */

  List<String> currentSubscriptionIDs = [];

  Map<String,dynamic> _configSettings = {};



  // This loop should run every 3 seconds to update the right panel based on listening to the websocket.
  Future<void> _fetchDataFromWebSocketBuffer() async {

    // handle special "home" case first.  The "home" is used when we do an action and
    // aren't sure how it might impact the existing room, or has known bad potential outcomes.
    // So, to be safe, just reset the room.  "home_done" is a variation on home just so we
    // don't keep repainting.


    if (_roomType == "home") {
      _RightPanelNotifier.value = [];
      _cachedWidgetData = [];
      _roomType = "home_done";
      return;
    }
    if (_roomType == "home_done") {
      return;
    }

    List<String> fetchedData = [];
    List<Map<String, String>> formattedData = [];

    if (_roomType == "fat_group") {
      fetchedData = websocketmanagermulti.collectWebSocketBufferAll();

      List<Map<String, dynamic>> latestMessageFromEachRelay = [];

      for (String dataString in fetchedData) {
        List<dynamic> singleData = jsonDecode(dataString);
        if (singleData.length >= 3 && singleData[2] is Map) {
          String relay = singleData[2]['relay'];
          String createdAt = singleData[2]['created_at'].toString();
          int socketId = singleData[2]['socket']; // Get the socket ID

          Map<String, dynamic> existingRelay = latestMessageFromEachRelay.firstWhere((item) => item['relay'] == relay, orElse: () => {});

          if (existingRelay.isEmpty) {
            latestMessageFromEachRelay.add({'relay': relay, 'createdAt': createdAt, 'socketId': socketId});
          } else if (int.parse(existingRelay['createdAt']) < int.parse(createdAt)) {
            existingRelay['createdAt'] = createdAt;
            existingRelay['socketId'] = socketId;
          }
        }
      }


      for (Map<String, dynamic> relayData in latestMessageFromEachRelay) {
        String relay = relayData['relay'];
        int createdAt = int.parse(relayData['createdAt']);
        int socketId = relayData['socketId'];

        String currentRequest="";
        try {
          currentRequest = websocketmanagermulti.getCurrentRequest(socketId);
        } catch (e) {
        }

        if (currentRequest != "") {
          String eTag = OG_util.getEtagValueFromRequest(currentRequest);
          if (eTag != "") {
            // Insert/Update the watermark for this composite key (group_relay) for the fatgroup.
              String compositeKey = eTag + "_" + relay;
              await OG_HiveInterface.updateOrInsert_MessagesFatGroupCacheWatermark(compositeKey, createdAt);


          }
        }

      }
    }

    else {
      //  NORMAL NON- FAT GROUP CASE.
      // Get anything new from the websocket buffer.
       fetchedData = websocketmanagermulti.collectWebSocketBuffer(0);
       int mostRecentTimeBeforeEOSE = OG_util.getMostRecentTimeBeforeEOSE(fetchedData);
       // Grab the original request message so we can get the group_id.
       String currentRequest=websocketmanagermulti.getCurrentRequest(0);
       String eTag = OG_util.getEtagValueFromRequest(currentRequest);
       if (eTag!="") {

         // if mostRecentTimeBeforeEOSE is 0, that means there were no events returned.  We only want to update the DB if its non-zero, otherwise we'll overwrite the watermark.

         mostRecentTimeBeforeEOSE--;
         if (mostRecentTimeBeforeEOSE>0) {
           try {
             await OG_HiveInterface.updateOrInsert_MessagesGroupCacheWatermark(
                 eTag, mostRecentTimeBeforeEOSE);
           } catch (e) {}
         }
       } // endif eTag != null


       List<dynamic> singleEvent=[];
       String my_event = "";
       String my_event_id ="";

       for (int i = fetchedData.length - 1; i >= 0; i--) {
         my_event = fetchedData[i];
         singleEvent = jsonDecode(my_event);

         //Grab the "EVENT" part of the event to get the subscription id.
         for (int i = 0; i < singleEvent.length - 1; i++) {
           if (singleEvent[i] == "EVENT") {
             my_event_id= singleEvent[i + 1];
             break;
           }
         }


         if (!currentSubscriptionIDs.contains(my_event_id)) {
           // If the event subscription is not one of our current subscriptions id, remove it.  This also handles EOSE messages returned from the relay, which we can ignore.
           fetchedData.removeAt(i);
         }

       } // End For loop


    }


    if (fetchedData.isNotEmpty) {
      processingWebSocketInfo.value = true;

      formattedData = await compute(
        nostr_core.processWebSocketData,
        {"fetchedData": fetchedData,  "configSettings": _configSettings},
      );

      formattedData = formattedData.where((singleItemMap) {
        String mySubscription = singleItemMap['subscription'] ?? "";
        return currentSubscriptionIDs.contains(mySubscription);
      }).toList();
      processingWebSocketInfo.value = false;
    }
    else {

      processingWebSocketInfo.value = false;
    }

    // Start creating a composite DB key
    String my_db_key = _rightPanelUniqueRowId + "_";

    // Direct message with a friend requires special handling to include both friends key and our user key in the composite key.
    if (_roomType == "friend") {
      Map<String, String> chosenAliasData =
          await OG_HiveInterface.getData_Chosen_Alias_Map();
      String my_alias = chosenAliasData?['alias'] ?? '';
      String my_user_pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(my_alias);
      //This will have a single underscore.  When passing to the DB classes, the extra underscore will be put in between the composite key and the row data.
      my_db_key = my_db_key + my_user_pubkey;
    }

    // Grab the cache
    List<Map<String, String>> dbData =  await fetchDbDataMessages(my_db_key, _roomType);

    // Merge the cache with the fresh websocket buffer data.
    List<Map<String, String>> mergedData = mergeDataMessages(dbData, formattedData);

    // Merge the data and do a repaint only if needed.
    mergedData.sort((b, a) =>
        int.parse(b['created_at']!).compareTo(int.parse(a['created_at']!)));
    if (!OG_util.areListsOfMapsEqual(mergedData, _cachedWidgetData) ||
        _oneTimeRepaintRightPanel) {
      _oneTimeRepaintRightPanel = false;
      await updateDbMessages(mergedData, my_db_key, _roomType);

      //render is a class that we invoke and call to get the widgets.
      List<Widget> freshWidgets = await render.fetchDataAndRenderWidgets(
          mergedData,
          context,
          _onMainCallback,
          _mainWebSocketURI,
          _roomType,
          _rightPanelUniqueRowId);

      // Now send the widgets to the right panel notifier.
      _RightPanelNotifier.value = freshWidgets;

      // Update the cache variable for next time.
      _cachedWidgetData = mergedData;
    }

  }  //end of fetchDataFromWebSocketBuffer

  // Get Cache Info depending on type
  Future<List<Map<String, String>>> fetchDbDataMessages(
      String my_db_key, String roomType) async {
    switch (roomType) {
      case "group":
        return await OG_HiveInterface.getMessagesForGroup(my_db_key);
      case "fat_group":
        return await OG_HiveInterface.getMessagesForFatGroup(my_db_key);
      case "friend":
        return await OG_HiveInterface.getMessagesForFriend(my_db_key);
      case "relay":
        return await OG_HiveInterface.getMessagesForRelay(my_db_key);
      default:
        return [];
    }
  }

  // This function just merges data from 2 lists -- the websocket data and the cache.
  List<Map<String, String>> mergeDataMessages(List<Map<String, String>> dbData,
      List<Map<String, String>> formattedData) {
    List<Map<String, String>> mergedData = List.from(dbData);

    for (Map<String, String> formattedItem in formattedData) {
      bool alreadyExists = false;
      for (Map<String, String> dbItem in mergedData) {
        if (dbItem['id'] == formattedItem['id']) {
          alreadyExists = true;
          break;
        }
      }
      if (!alreadyExists) {
        mergedData.add(formattedItem);
      }
    }

    return mergedData;
  }

  // This function updates the DB cache.
  Future<void> updateDbMessages(List<Map<String, String>> mergedData,
      String my_db_key, String roomType) async {
    switch (roomType) {
      case "group":
        await OG_HiveInterface.addData_MessagesGroup(my_db_key, mergedData,
            WipePreviousCacheforComposite: true);
        break;
      case "fat_group":
        await OG_HiveInterface.addData_MessagesFatGroup(my_db_key, mergedData,
            WipePreviousCacheforComposite: true);
        break;
      case "friend":
        await OG_HiveInterface.addData_MessagesFriend(my_db_key, mergedData,
            WipePreviousCacheforComposite: true);
        break;
      case "relay":
        await OG_HiveInterface.addData_MessagesRelay(my_db_key, mergedData,
            WipePreviousCacheforComposite: true);
        break;
      default:
        break;
    }
  }

  // This is a primary function for establishing a websocket connection and sending
  // the main query.
  Future<void> freshWebSocketConnectandSend(String websocketURIs, String message,
      {String? secondary_message, bool storeRequest = false, bool multiSend = false}) async {
    // Get the subscription IDs
    List<dynamic> messageList = jsonDecode(message);
    for (int i = 0; i < messageList.length - 1; i++) {
      if (messageList[i] == "REQ") {
        currentSubscriptionIDs.add(messageList[i + 1]);
        break;
      }
    }

    if (secondary_message != null) {
      List<dynamic> messageList2 = jsonDecode(secondary_message);
      for (int i = 0; i < messageList2.length - 1; i++) {
        if (messageList2[i] == "REQ") {
          currentSubscriptionIDs.add(messageList2[i + 1]);
          break;
        }
      }
    }

    if (!multiSend) {
      String websocketURI = websocketURIs;
      await _initWebSocketConnection(websocketURI);

      if (OG_util.isKind42Request(message)) {
        int watermark_since = 0;
        String eTag = OG_util.getEtagValueFromRequest(message);
        try {
          Map<String, dynamic> groupCacheMap = await OG_HiveInterface
              .getData_GroupCacheWatermark(eTag);
          watermark_since = groupCacheMap['createdAt'] == null
              ? 0
              : int.parse(groupCacheMap['createdAt']);
        } catch (e) {
          print(e);
        }
        // Include watermark in the query
        message =
            OG_util.addTimeStampFiltersToQuery(message, since: watermark_since);
      }

      bool websocketStatus = websocketmanagermulti.isWebSocketOpen(0);

      if (websocketStatus) {
        await websocketmanagermulti.send(
            0, message, storeRequest: storeRequest);
        if (secondary_message != null) {
          Future.delayed(Duration(milliseconds: 100), () {});
          await websocketmanagermulti.send(0, secondary_message);
        }
      } else {
        print('WebSocket is not open, cannot send message');
        return;
      }
    }

    if (multiSend) {
      List<String> websocketURIList = websocketURIs.split(',');
      List<Future<void>> primaryMessageFutures = [];
      List<Future<void>> secondaryMessageFutures = [];

      for (String websocketURI in websocketURIList) {
        websocketURI = websocketURI.trim();
        int socketId = websocketmanagermulti.getCleanSocketId();
        await _initWebSocketConnection(websocketURI, socketId: socketId);

        String relay = websocketURI;
        String eTag = OG_util.getEtagValueFromRequest(message);
        String compositeKey = eTag + "_" + relay;
        Map<String, dynamic> groupCacheMap = await OG_HiveInterface
            .getData_FatGroupCacheWatermark(compositeKey);

        if (OG_util.isKind42Request(message)) {
          int watermark_since = groupCacheMap['createdAt'] == null
              ? 0
              : int.parse(groupCacheMap['createdAt']);
          message = OG_util.addTimeStampFiltersToQuery(
              message, since: watermark_since);
        }

        if (websocketmanagermulti.getStatus(socketId) == 1) {
          primaryMessageFutures.add(websocketmanagermulti.send(
              socketId, message, storeRequest: storeRequest));

          if (secondary_message != null) {
            secondaryMessageFutures.add(
                websocketmanagermulti.send(socketId, secondary_message));
          }
        } else {
          print('WebSocket is not open, cannot send message');
          return;
        }
// Wait for all primary messages to be sent
        await Future.wait(primaryMessageFutures);

// Pause for 100ms
        await Future.delayed(Duration(milliseconds: 100));

// Wait for all secondary messages to be sent
        await Future.wait(secondaryMessageFutures);
      }
    }
  }

      // A simple wrapper function before opening the websocket.
  Future<void> _initWebSocketConnection(String websocketURI,{int socketId=0}) async {
    try {
      int connected = 1; // start in error state. 0 = connected.
      connected = await websocketmanagermulti.openPersistentWebSocket(socketId,websocketURI);
      setState(() {

      });
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      setState(() {
      });
    }
  }

  // Show or Hide the Emoji Picker Widget
  void toggleEmojiPicker() {
    if (!_emojiPickerVisible) {
      _emojiPickerVisible = true;
      _buildEmojiPickerOverlay(context).then((_) {
        // Update isEmojiPickerActive flag
        isEmojiPickerActive.value = true;

      });
    } else {
      _emojiPickerOverlay?.remove();
      _emojiPickerOverlay = null;
      _emojiPickerVisible = false;
      // Update isEmojiPickerActive flag
      isEmojiPickerActive.value = false;
    }
  }


  // This builds the left pane
  Future<void> _fetchAndUpdateRowCache() async {
    List<Future> futures = [
      fetchRelayList(),
      fetchFriendsList(),
      fetchGroupsList(),
      fetchFatGroupsList(),
    ];

    try {

      List responses = await Future.wait(futures);
      await _updateRowCacheIfNeeded(
        relayListData: responses[0],
        friendsListData: responses[1],
        groupListData: responses[2],
        fatGroupListData: responses[3],
      );
    } catch (e) {
      print("Error fetching lists: $e");
    }
  }

  // Used for the reply widget.
  void updateShowReplyWidget(bool value) {
    setState(() {
      showReplyWidget = value;
    });
  }

  // This function is for getting the focus back after we disable it for things like the reply widget.
  void regainMainWindowFocus() {
    shouldRightPanelRequestFocus.value = true;
  }

// Get the wallpaper for the background from the config settings.
  Future<void> getWallpaper() async {
    _wallPaperString = 'assets/images/wallpapers/BLUE.png';

    String wallPaper = "";
    Map<String, dynamic>? configMap =
        await OG_HiveInterface.getData_ConfigSettings();
    if (configMap != null) {
      if (configMap['wallpaper'] != null) {
        wallPaper = configMap['wallpaper'];
      }
    }
    if (wallPaper != "") {
      _wallPaperString = 'assets/images/wallpapers/' + wallPaper + '.png';
    }

  }

  // Set reply tags into the class variables
  void setReplyTags(String eTag, String pTag) {
    setState(() {
      _eTagReply = eTag;
      _pTagReply = pTag;
    });
  }

  // Set the class variable for the sort style
  void toggleLeftPaneSortStyle() {
    if (_leftPaneSortStyle == 0) {
      _leftPaneSortStyle = 1;
    } else if (_leftPaneSortStyle == 1) {
      _leftPaneSortStyle = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    getWallpaper();
    _cachedWidgetData = [];
    loadConfigSettings();
    Timer.periodic(Duration(seconds: 3), (timer) {
      _fetchDataFromWebSocketBuffer();
    });

    // Not really an error but use the errorBubble class to display a welcome message on startup.
    List<Widget> welcomeWidgets =
        ui_helper.errorBubble("Welcome to OstrichGram!", " ", msgColor: Colors.blueGrey);
    _RightPanelNotifier = ValueNotifier(welcomeWidgets);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchAndUpdateRowCache(); // For the left panel
    });
  }

  Future<void> loadConfigSettings() async {
    Map<String, dynamic> configSettings = await OG_HiveInterface.getData_ConfigSettings();
    if (mounted) { // Check if the widget is still mounted
      setState(() {
        _configSettings = configSettings;
      });
    }
  }

  // _processCallback is a large function that does the heavy lifting for any callback event.
  Future<void> _processCallback(String eventType, String unique_id,
      {Map<String, dynamic>? aux_data}) async {

    /*
    EVENT TYPES:
    right_click_edit_friend
    right_click_user_icon_addFriend
    right_click_user_icon_copyID
    right_click_delete_friend
    right_click_copy_friendID
    left_click_friend
    left_click_left_panel_group
    kind40_left_click
    left_click_relay
    right_click_open_relay
    kind40_right_click_copy_groupID
    right_click_copy_group_id
    right_click_remove_relay
    right_click_remove_group
    right_click_group_chat_msg_reply
    left_click_left_panel_fat_group'
    kind40_fat_left_click
    right_click_fat_group_view_relays
    right_click_copy_fat_group_id
     */


    if (eventType == 'right_click_fat_group_view_relays') {
      String group_id = unique_id;
      String metadata_relays="";
      try {
        Map <String,dynamic> fatGroupMap = await OG_HiveInterface.getData_FatGroupMap(group_id);
        metadata_relays = fatGroupMap['metadata_relays'];
      } catch(e) {
        print (e);
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Relays:'),
            content: Text(metadata_relays),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the info dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }

    // Show the event dialog for editing a friend
    if (eventType == 'right_click_edit_friend') {
      String pubkey = unique_id;
      _showEditFriendDialog(context, pubkey);
      _roomType =
          "home"; // If editing the contact, I don't want the unique id to somehow mess up the right side... Err on side of saftey and reset the right side to home.
      _rightPanelRoomName = "";
      _rightPanelUniqueRowId = "none";
      _oneTimeRepaintRightPanel = true;
    }

    // Show the dialog for adding a contact, but prefill the npub.
    if (eventType == 'right_click_user_icon_addFriend') {
      String friend_npub = "";
      String prefix = "npub";
      try {
        friend_npub = nostr_core.hexToBech32(unique_id, prefix);
      } catch (e) {
        friend_npub = "";
        print("error getting bech32, unknown cause in main dart.");
      }
      showAvatarSelectionDialog(context, preFilledNpub: friend_npub);
    }

    // Copy the user key to clipboard from the icon
    if (eventType == 'right_click_user_icon_copyID') {
      String friend_npub = "";
      String prefix = "npub";

      try {
        friend_npub = nostr_core.hexToBech32(unique_id, prefix);
      } catch (e) {
        friend_npub = "";
        print("error getting bech32, unknown cause in main dart.");
      }

      await Clipboard.setData(ClipboardData(text: friend_npub));
    }

    // Delete a contact from the DB and fresh the panels.
    if (eventType == 'right_click_delete_friend') {
      String pubkey = unique_id;
      await OG_HiveInterface.deleteFriendByPubkey(pubkey);
      await OG_HiveInterface.removeMessagesForFriend(pubkey);
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
      if (_rightPanelUniqueRowId == unique_id) {
        // If we got here, it means we deleted the friend that
        // was open on the right panel, so clear everything.
        setState(() {
          _rightPanelUniqueRowId = "deleted";
          _rightPanelRoomName = "";
          _roomType = "home";
          _oneTimeRepaintRightPanel = true;
        });
      }
    }

    // Copy the user key via right click copy
    if (eventType == 'right_click_copy_friendID') {
      String pubkey = unique_id;
      String hex = pubkey;
      String prefix = "npub";

      // Convert hex to Bech32
      String friend_npub = "";
      try {
        friend_npub = nostr_core.hexToBech32(hex, prefix);
      } catch (e) {
        friend_npub = "";
        print("error getting bech32, unknown cause in main dart.");
      }
      if (friend_npub.length >= 4 && friend_npub.substring(0, 4) == "npub") {
        await Clipboard.setData(ClipboardData(text: friend_npub));
      } else {
        // This shouldn't happen, but it's better to return an empty clipboard than something weird
        await Clipboard.setData(ClipboardData(text: " "));
      }
    }

    // Left click on a friend row opens up the DM chat
    if (eventType == 'left_click_friend') {
      String friend_pubkey = unique_id;

      String friend_label = "";
      if (aux_data != null) {
        friend_label = aux_data['friend_name'];
      }
      // Set the clicked item to the top and refresh the left panel
      String left_panel_position =
          await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position =
          (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      await Future(() => OG_HiveInterface.setLeftPanelPositionFriend(
          friend_pubkey, left_panel_position));
      // Now Refresh Left Side
      setState(() {
        _shouldUpdateRowCache = true;
      });

      await Future(() => _fetchAndUpdateRowCache());
      _roomType = "friend";
      _rightPanelUniqueRowId = friend_pubkey;
      _rightPanelRoomName = friend_label;

      Map<String, dynamic> friendMap =
          await OG_HiveInterface.getData_FriendMapFromPubkey(friend_pubkey);
      String? relay_for_DM = friendMap['relay_for_DM']?.toString();
      if (relay_for_DM == null) {
        relay_for_DM = "";
      }

      // Make sure there's a relay set for the user.
      if (relay_for_DM.trim() == "") {
        _RightPanelNotifier.value = ui_helper.errorBubble(
            "No 'Relay for DM' set for this contact.",
            "Edit this contact and specify a relay before starting a chat.");
        return;
      } else {
        String user_pubkey = "";
        Map<String, String> chosenAliasData =
            await OG_HiveInterface.getData_Chosen_Alias_Map();
        String alias = chosenAliasData?['alias'] ?? '';
        user_pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);

        // We need two messages, one for "from" , the other for "to".
        String requestKind04s_TOUSER =
            nostr_core.constructJSON_fetch_kind_04s(friend_pubkey, user_pubkey);

        String requestKind04s_FROMUSER =
            nostr_core.constructJSON_fetch_kind_04s(user_pubkey, friend_pubkey);

        // Open the websocket and send both queries.
        try {
          await freshWebSocketConnectandSend(
              relay_for_DM, requestKind04s_TOUSER,
              secondary_message: requestKind04s_FROMUSER);
        } catch (e) {
          print(
              'something went wrong trying to call freshWebSocketConnectandSend from main.dart');
          print(e);
        }
      }
    } // end left click friend


    // These are for opening up a group, whether from the left panel or from the right panel within a relay room.
    if (eventType == 'left_click_left_panel_fat_group' ||
        eventType == 'kind40_fat_left_click') {
      String fatgroup = unique_id;

      // Keep track of the left panel position so we get a nice ordering of widgets.
      // Each time a new click happens, set the left panel position for the row
      // equal to the highest number plus one.
      String left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      bool fatGroup_Exists;
      fatGroup_Exists = await OG_HiveInterface.fatGroupExists(fatgroup);

      // The group may not exist yet in our list if we're clicking on it in the right panel for the first time.
      if (!fatGroup_Exists) {
        try {
          if (aux_data != null) {
            await OG_HiveInterface.addData_FatGroups(fatgroup, left_panel_position,
                aux_data: aux_data);
          } else {
            throw Exception('Aux data is null');
          }
        } catch (e) {
          print(" $e");
        }
      } else {
        // The group already exists,  set the left panel position.
        await Future(() => OG_HiveInterface.setLeftPanelPositionFatGroup(
            fatgroup, left_panel_position));
      }

     Map<String,dynamic> fatGroupMap = await OG_HiveInterface.getData_FatGroupMap(fatgroup);

      String relays="";

      if ( fatGroupMap['metadata_relays'] != null) {
        relays = fatGroupMap['metadata_relays'];
      }

      String e_tag = unique_id;

      final globalConfig = GlobalConfig();
      int numberItemsToFetch=globalConfig.message_limit;

      // Fetch all messages in the group.
     String requestKind42s = nostr_core.constructJSON_fetch_kind_42s(e_tag,numberItemsToFetch);
      // Get the group name.
      String group_label = "";
      if (aux_data != null) {
        if (aux_data['group_name'] != null) {
          group_label = aux_data['group_name'];
        }
      }

      // Call the function to update the right panel
      setState(() {
        // After we re-establish the websocket connection, set the class variables
        _mainWebSocketURI = "multi"; // Assign the newly selected relay to the class variable.
        _roomType = "fat_group"; // action was left_click_left_panel_group
        _rightPanelUniqueRowId = unique_id;
        _rightPanelEventType = eventType;
        _rightPanelRoomName = group_label;
      });

      // Fetch the group chat messages via the websocket.
      try {
        WebSocketManagerMulti().closeAllWebSocketConnections();
        await freshWebSocketConnectandSend(relays, requestKind42s,storeRequest: true, multiSend: true);
      } catch (e) {
        print(
            "There was a problem establishing a new websocket connection: $e");
      }

      // Set the clicked item to the top and refresh the left panel
      left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      await Future(() => OG_HiveInterface.setLeftPanelPositionFatGroup(fatgroup, left_panel_position));
      // Now Refresh Left Side
      setState(() {
        _shouldUpdateRowCache = true;
      });

      // Update the left panel.
      await Future(() => _fetchAndUpdateRowCache());
    }

    // These are for opening up a group, whether from the left panel or from the right panel within a relay room.
    if (eventType == 'left_click_left_panel_group' ||
        eventType == 'kind40_left_click') {
      String group = unique_id;


      // Keep track of the left panel position so we get a nice ordering of widgets.
      // Each time a new click happens, set the left panel position for the row
      // equal to the highest number plus one.
      String left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      bool group_Exists;
      group_Exists = await OG_HiveInterface.groupExists(group);

      // The group may not exist yet in our list if we're clicking on it in the right panel for the first time.
      if (!group_Exists) {
        try {
          if (aux_data != null) {
            await OG_HiveInterface.addData_Groups(group, left_panel_position,
                aux_data: aux_data);
          } else {
            throw Exception('Aux data is null');
          }
        } catch (e) {
          print(" $e");
        }
      } else {
        // The group already exists,  set the left panel position.
        await Future(() => OG_HiveInterface.setLeftPanelPositionGroup(
            group, left_panel_position));
      }

      // We need the e_tag which is the group ID.
      String relay = unique_id.split(',')[1].trim();
      String e_tag = unique_id.split(',')[0].trim();

      final globalConfig = GlobalConfig();
      int numberItemsToFetch=globalConfig.message_limit;

      // Fetch all messages in the group.
      String requestKind42s = nostr_core.constructJSON_fetch_kind_42s(e_tag,numberItemsToFetch);

      // Get the group name.
      String group_label = "";
      if (aux_data != null) {
        if (aux_data['group_name'] != null) {
          group_label = aux_data['group_name'];
        }
      }


      // Call the function to update the right panel
      setState(() {
        // After we re-establish the websocket connection, set the class variables
        _mainWebSocketURI =
            relay; // Assign the newly selected relay to the class variable.
        _roomType = "group"; // action was left_click_left_panel_group
        _rightPanelUniqueRowId = unique_id;
        _rightPanelEventType = eventType;
        _rightPanelRoomName = group_label;
      });

      // Fetch the group chat messages via the websocket.
      try {
        await freshWebSocketConnectandSend(relay, requestKind42s,storeRequest: true);
      } catch (e) {
        print(
            "There was a problem establishing a new websocket connection: $e");
      }

      // Set the clicked item to the top and refresh the left panel
      left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      await Future(() => OG_HiveInterface.setLeftPanelPositionGroup(group, left_panel_position));
      // Now Refresh Left Side
      setState(() {
        _shouldUpdateRowCache = true;
      });

      // Update the left panel.
      await Future(() => _fetchAndUpdateRowCache());
    }

    // These will open up the relay in the right panel.
    if (eventType == 'left_click_relay' || eventType == 'right_click_open_relay') {
      String relay = unique_id;
      _roomType = "relay";

      String left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
      await Future(() => OG_HiveInterface.setLeftPanelPositionRelay(relay, left_panel_position));

      // Now Refresh Left Side
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());

      // Create the query.
      String requestKind40s = nostr_core.constructJSON_fetch_kind_40s();

      String requestKind41s = nostr_core.constructJSON_fetch_kind_41s();


      // Call the function to update the right panel
      setState(() {
        // Set the class variables for the right side.
        _mainWebSocketURI = relay; // Assign the newly selected relay to the class variable.
        _rightPanelUniqueRowId = unique_id;
        _rightPanelEventType = eventType;
        _rightPanelRoomName = relay;
      });

      // Pass the query to the websocket.
      try {
        await freshWebSocketConnectandSend(relay, requestKind40s,secondary_message: requestKind41s);
      } catch (e) {
        print(
            "There was a problem establishing a new websocket connection: $e");
      }
    }

    // Copy the group ID to the clipboard from the right pane.
    if (eventType == 'kind40_right_click_copy_groupID') {
      String group = unique_id;
      String firstItem = group.split(',')[0].trim();
      await Clipboard.setData(ClipboardData(text: firstItem));
    }


// Copy the group ID to the clipboard from the left pane.
if (eventType == 'right_click_copy_fat_group_id') {
  String group = unique_id;
  await Clipboard.setData(ClipboardData(text: group));
}


// Copy the group ID to the clipboard from the left pane.
    if (eventType == 'right_click_copy_group_id') {
      String group = unique_id;

      String firstItem = group.split(',')[0].trim();
      await Clipboard.setData(ClipboardData(text: firstItem));
    }

    // Add the fatgroup from a right click on the right side.

    if (eventType == 'kind40_right_click_add_fat_group') {
      // First add the Group to the DB.
      String fatgroup = unique_id;
      String left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE


      bool fatgroup_Exists;
       fatgroup_Exists = await OG_HiveInterface.fatGroupExists(fatgroup);

      if (!fatgroup_Exists) {
        try {
          if (aux_data != null) {
            await OG_HiveInterface.addData_FatGroups(fatgroup, left_panel_position,
                aux_data: aux_data);
          } else {
            throw Exception('Aux data is null');
          }
        } catch (e) {
          print(" $e");
        }
      } else {
        // The group already exists,  set the left panel position.
        await Future(() => OG_HiveInterface.setLeftPanelPositionFatGroup(
            fatgroup, left_panel_position));
      }
// Get the group name.
      String group_label = "";
      if (aux_data != null) {
        if (aux_data['group_name'] != null) {
          group_label = aux_data['group_name'];
        }
      }


      // Call the function to update the right panel
      setState(() {
        // After we re-establish the websocket connection, set the class variables
          //also update left side
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
    }

    // Add the group from a right click on the right side.
    if (eventType == 'kind40_right_click_add_group') {
      // First add the Group to the DB.
      String group = unique_id;
      String left_panel_position = await OG_HiveInterface.get_Highest_Left_Panel_Position();
      left_panel_position = (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE

      bool group_Exists;
      group_Exists = await OG_HiveInterface.groupExists(group);

      if (!group_Exists) {
        try {
          if (aux_data != null) {
            await OG_HiveInterface.addData_Groups(group, left_panel_position,
                aux_data: aux_data);
          } else {
            throw Exception('Aux data is null');
          }
        } catch (e) {
          print(" $e");
        }
      } else {
        // The group already exists,  set the left panel position.
        await Future(() => OG_HiveInterface.setLeftPanelPositionGroup(
            group, left_panel_position));
      }

      // Now Refresh Left Side
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
    }

    // Delete the relay from our list.
    if (eventType == 'right_click_remove_relay') {
      String relay = unique_id;
      await OG_HiveInterface.deleteRelay(relay);
      await OG_HiveInterface.removeMessagesForRelay(relay);
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
      if (_rightPanelUniqueRowId == relay) {
        // If we got here, it means we deleted the relay that
        // was open on the right panel, so clear everything.
        setState(() {
          _rightPanelUniqueRowId = "deleted";
          _roomType = "home";
          _rightPanelRoomName = "";
          _oneTimeRepaintRightPanel = true;
        });
      }
    }

    // Delete the group from our list.
    if (eventType == 'right_click_remove_group') {
      String group = unique_id;
      await OG_HiveInterface.deleteGroup(group);
      await OG_HiveInterface.removeMessagesForGroup(group);
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
      if (_rightPanelUniqueRowId == group) {
        // If we got here, it means we deleted the group that
        // was open on the right panel.
        setState(() {
          _rightPanelUniqueRowId = "deleted";
          _roomType = "home";
          _rightPanelRoomName = "";
          _oneTimeRepaintRightPanel = true;
        });
      }
    }

    // Delete the fat group from our list.
    if (eventType == 'right_click_remove_fat_group') {
      String fatgroup = unique_id;
      await OG_HiveInterface.deleteFatGroup(fatgroup);
      await OG_HiveInterface.removeMessagesForFatGroup(fatgroup);
      setState(() {
        _shouldUpdateRowCache = true;
      });
      await Future(() => _fetchAndUpdateRowCache());
      if (_rightPanelUniqueRowId == fatgroup) {
        // If we got here, it means we deleted the group that
        // was open on the right panel.
        setState(() {
          _rightPanelUniqueRowId = "deleted";
          _roomType = "home";
          _rightPanelRoomName = "";
          _oneTimeRepaintRightPanel = true;
        });

        setState(() {
          _rightPanelUniqueRowId = "deleted";
          _roomType = "home";
          _rightPanelRoomName = "";
          _oneTimeRepaintRightPanel = true;
        });

      }
  }


    // Reply to a message (NIP 10).  Get the data to pass to the reply widget.
    if (eventType == 'right_click_group_chat_msg_reply') {

      // Set the info for the reply widget on the UI, as that is the first thing that happens
      // when you right click reply.

      String reply_e_tag = "";
      String reply_p_tag = "";

      if (aux_data != null) {
        if (aux_data['id'] != null) {
          reply_e_tag = aux_data['id'];
        }
        if (aux_data['pubkey'] != null) {
          reply_p_tag = aux_data['pubkey'];
        }
        if (aux_data['content'] != null) {
          replyMessageText = aux_data['content'];
        }


        if (aux_data['pubkey'] != null) {
          String displayName = await OG_HiveInterface.getData_FriendFromPubkey(aux_data['pubkey']);
          if (displayName.isNotEmpty) {
            replyDisplayName = displayName.length <= 30 ? displayName : displayName.substring(0, 30);
          } else {

            String some_message_pubkey = aux_data['pubkey'];

            String replyWidgetnPubString = "";
            String prefix = "npub";
            try {
              replyWidgetnPubString = nostr_core.hexToBech32(some_message_pubkey, prefix);
            } catch (e) {
              print ('problem converting friend key to npub in main dart.');
            }

            replyDisplayName = replyWidgetnPubString.length <= 30 ? replyWidgetnPubString: replyWidgetnPubString.substring(0, 30);
          }
        }

        //--
      }

      // Set the reply tags and show the widget.
      setReplyTags(reply_e_tag, reply_p_tag);
      updateShowReplyWidget(true);

      // Set the right panel focus to false otherwise the reply widget won't be visible as the focus will get stolen.
      shouldRightPanelRequestFocus.value = false;

      // Put the focus on the input bar so it knows the information.
      _inputBarKey.currentState?.requestFocus();
    }// END EVENT TYPE.


    // call setState to update anything we did at the beginning for a room change, etc
    setState(() {
      _shouldUpdateRowCache = true;
    });
  } // END OF PROCESS CALLBACK

  // Determine if we are "changing rooms".  Not all events are a room change.

  bool _roomChange(String eventType, String unique_id) {

    // Should be safe to say there's no room change if the ID didn't change (fat groups are an exception because we want to reset the websockets).

    if (unique_id == _rightPanelUniqueRowId) {
      return false;
    }

    // Assume its a room change unless it's one of these:
    List<String> nonRoomChangeEvents = [
      'right_click_group_chat_msg_reply',
      'right_click_group_chat_copy_text',
      'kind40_right_click_copy_groupID',
      'kind40_right_click_add_group',
      'right_click_copy_group_id',
      'right_click_copy_friendID',
      'left_click_group_chat_msg',
      'user_icon_tap',
      'right_click_user_icon_copyID',
      'right_click_user_icon_addFriend',
      'right_click_delete_friend',
      'right_click_remove_relay',
      'right_click_remove_group',
      'right_click_fat_group_view_relays',
      'kind40_right_click_add_fat_group'

    ];

    if (nonRoomChangeEvents.contains(eventType)) {
      return false;
    } else {
      return true;
    }
  }

  // This is entry point for callbacks.
  Future<void> _onMainCallback(String eventType, String unique_id,
      {Map<String, dynamic>? aux_data}) async {

    if (_roomChange(eventType, unique_id)) {

      // If there's a room change, first close the websocket.
      WebSocketManagerMulti().closeAllWebSocketConnections();


      updateShowReplyWidget(false);
      // Next, clear the wiedgets.
      _RightPanelNotifier.value = [];
      _rightPanelUniqueRowId = unique_id;
      _roomType =  "" ; // No room type yet, this will be defined a bit later when we call _processCallback.
      _cachedWidgetData = [];
      currentSubscriptionIDs = [];
    }

    await _processCallback(eventType, unique_id, aux_data: aux_data);
  }

  // Updates the Left Panel
  Future<void> _updateRowCacheIfNeeded({
    required List<dynamic> relayListData,
    required List<dynamic> friendsListData,
    required List<dynamic> groupListData,
    required List<dynamic> fatGroupListData,
  }) async {
    if (_shouldUpdateRowCache) {
      _cachedRowItems = await ui_helper.getLeftPaneListItems(
          context,
          _onMainCallback,
          relayListData,
          groupListData,
          fatGroupListData,
          friendsListData,
          _leftPaneSortStyle);
      _shouldUpdateRowCache = false;

      setState(() {
        _dataReady = true;
      });
    }
  }

  // This function fetches a list of relays from the DB
  static Future<List> fetchRelayList() async {
    await OG_HiveInterface.initRelaysBox();
    List<dynamic> data =
        await OG_HiveInterface.getListofRelays(); // Fetch the data from DB
    return data;
  }

  // This function fetches a list of chat groups from the DB
  static Future<List> fetchGroupsList() async {
    await OG_HiveInterface.initGroupsBox();
    List<dynamic> data =
        await OG_HiveInterface.getListofGroups(); // Fetch the data from DB
    return data;
  }

  // This function fetches a list of chat groups from the DB
  static Future<List> fetchFatGroupsList() async {
    await OG_HiveInterface.initFatGroupsBox();
    List<dynamic> data =
    await OG_HiveInterface.getListofFatGroups(); // Fetch the data from DB
    return data;
  }


  // This function fetches a list of contacts from the DB
  static Future<List> fetchFriendsList() async {
    await OG_HiveInterface.initFriendsBox();
    List<dynamic> data =
        await OG_HiveInterface.getListofFriends(); //Fetch the data from DB
    return data;
  }

  // This function creates the dialog to edit a contact.
  void _showEditFriendDialog(BuildContext context, String pubkey) async {
    // Dummy database data
    String npub = "";
    String my_avatar_style = "00";

    if (pubkey == null) {
      return;
    }

    try {
      npub = (nostr_core.hexToBech32(pubkey, "npub"));
    } catch (e) {
      print(e);
      return;
    }

    Map<String, dynamic> friendData =
        await OG_HiveInterface.getData_FriendMapFromPubkey(pubkey);
    String fetchedName = friendData['friend'];
    String? fetchedRelay = friendData['relay_for_DM'];
    String? fetchedAvatarStyle = friendData['avatar_style'];

    if (fetchedAvatarStyle != null) {
      if (fetchedAvatarStyle != "") {
        my_avatar_style = fetchedAvatarStyle;
      }
    }

    // Generate the avatar icon for our friend.
    DrawableRoot svgRoot = await ui_helper.generateAvatar(pubkey, themeOverride: my_avatar_style);

    final TextEditingController _nameController =
        TextEditingController(text: fetchedName);
    final TextEditingController _relayController =
        TextEditingController(text: fetchedRelay);

    final ValueNotifier<String> _errorMessage = ValueNotifier<String>('');

    // Function within a function to process the form.
    void _processEditFriendForm() async {
      String name = _nameController.text;
      String relay = _relayController.text;

      try {
        await Future(() =>
            OG_HiveInterface.updateData_Friends_UpdateNameandRelay(
                pubkey, name, relay));
        Navigator.of(context).pop();
      } catch (e) {
        print(e);
        String errorMessage = e.toString();
        if (errorMessage.startsWith('exception:', 0)) {
          errorMessage = errorMessage.replaceFirst('exception:', '');
        } else if (errorMessage.startsWith('Exception:', 0)) {
          errorMessage = errorMessage.replaceFirst('Exception:', '');
        }
        _errorMessage.value = errorMessage.trim();
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Container(
                    width: 500,
                    height: 500,
                    child: AlertDialog(
                      title: Text('Edit Contact: $fetchedName'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CustomPaint(
                              painter: MyPainter60(svgRoot, Size(60, 60)),
                              size: Size(60, 60),
                            ),
                            SizedBox(height: 10),
                            Text('$npub'),
                            SizedBox(height: 10),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(labelText: 'Name'),
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _relayController,
                              decoration:
                                  InputDecoration(labelText: 'Relay for DMs'),
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: 10),
                            ValueListenableBuilder(
                              valueListenable: _errorMessage,
                              builder: (BuildContext context, String value,
                                  Widget? child) {
                                return Text(
                                  value,
                                  style: TextStyle(color: Colors.red),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text('Submit'),
                          onPressed: () {
                            _processEditFriendForm();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // This function creates the dialog grid for choosing an avatar style
  void showAvatarSelectionDialog(BuildContext context,
      {String preFilledNpub = ""}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int _selectedAvatarIndex = 0;
        TextEditingController _nameController = TextEditingController();
        TextEditingController _keyController =
            TextEditingController(text: preFilledNpub);

        TextEditingController _relayforDMController = TextEditingController();
        String _errorMessage = "";

        // Generate the list of avatar futures outside the builder
        List<Future<Widget>> avatarFutures = List.generate(
            16, (index) => ui_helper.getAvatarSvgforContactCreate(index));

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Add New Contact'),
              content: Container(
                width: 350.0,
                height: 600.0,
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Contact Name'),
                    ),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(labelText: 'Contact Key'),
                    ),
                    TextField(
                      controller: _relayforDMController,
                      decoration:
                      InputDecoration(labelText: 'Relay for DM (optional)'),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      "Avatar Style", // Added text widget
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    SizedBox(height: 8.0),
                    Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                    ),
                    Expanded(

                    child: Center(
                        child: Container(
                          width: 300.0,
                          height: 400.0,
                          child: GridView.builder(
                            itemCount: 16,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 4.0,
                              mainAxisSpacing: 4.0,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAvatarIndex = index;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0),
                                    color: (_selectedAvatarIndex == index
                                        ? Colors.blue[300]
                                        : Colors.blue[100])!,
                                    border: _selectedAvatarIndex == index
                                        ? Border.all(
                                            color: Colors.blue[900]!,
                                            width: 3.0)
                                        : null,
                                  ),
                                  child: Center(
                                    child: FutureBuilder(
                                      future: avatarFutures[index],
                                      builder: (BuildContext context,
                                          AsyncSnapshot<Widget> snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.done) {
                                          if (snapshot.hasError) {
                                            // Return an error widget or an empty Container if there is an error.
                                            return Container();
                                          } else {
                                            return snapshot.data!;
                                          }
                                        } else {
                                          // Show a CircularProgressIndicator while waiting for the future to complete.
                                          return CircularProgressIndicator();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    String pubkey = _keyController.text.trim();
                    String relay_for_DM = _relayforDMController.text.trim();
                    bool validHexFormat = true;
                    RegExp regExp = RegExp(r'^[0-9A-Fa-f]+$');

                    if (!regExp.hasMatch(pubkey)) {
                      validHexFormat = false;
                    }
                    if (pubkey.length != 64) {
                      validHexFormat = false;
                    }

                    String converted_key = "";
                    try {
                      converted_key = (nostr_core.bech32ToHex(pubkey));
                    } catch (e) {
                      print("$e bech32 failed with invalid input.");
                    }

                    if (converted_key.length == 64) {
                      pubkey = converted_key;
                      _keyController.text =
                          converted_key; // Update the key controller with the converted hex value
                      validHexFormat = true;
                    }

                    if (validHexFormat) {
                      int avatarStyle = _selectedAvatarIndex;

                      attemptToUpdateContact(_nameController.text,
                              _keyController.text, avatarStyle, relay_for_DM)
                          .then((result) {
                        if (result == null) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            _errorMessage = result;
                          });
                        }
                      }).catchError((error) {
                        setState(() {
                          _errorMessage = error.toString();
                        });
                      });
                    } else {
                      setState(() {
                        _errorMessage = "Invalid hex key format";
                      });
                    }
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // This function is called after the dialog window, we are inserting a contact.
  Future<String?> attemptToUpdateContact(
      String name, String key, int avatarStyle, String relay_for_DM) async {
//adding a new contact if the operation is successful ==>
    String left_panel_position =
        await OG_HiveInterface.get_Highest_Left_Panel_Position();
    left_panel_position =
        (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
    try {
      // Attempt to update the contact data here.
      await OG_HiveInterface.addData_Friends(
          name, key, avatarStyle.toString(), left_panel_position, relay_for_DM);
    } catch (e) {
      // If an exception occurs, return the error message as a string.
      return e.toString();
    }
    setState(() {
      _shouldUpdateRowCache = true;
      // Force a repaint immediately.
      _oneTimeRepaintRightPanel = true;
    });
    await Future(() => _fetchAndUpdateRowCache());
  }

  // This function is called after filling out the new relay dialog to insert new relay into the DB
  Future<String?> handleInsertRelay(String relay) async {
    String? retval = await attemptToInsertRelay(relay);
    setState(() {
      _shouldUpdateRowCache = true;
    });
    await Future(() => _fetchAndUpdateRowCache());
    return retval;
  }


  // This function is called after filling out the create fat group dialog
  Future<String?> handleCreateFatGroup(String group_name, String group_about, String relays) async {

    // Do some basic validation first.
    if (group_name == "") {
      String err_msg = "Group name cannot be empty.";
      return err_msg;
    }

    if (group_name.length > 50 ) {
      String err_msg = "Group name cannot be more than 50 characters.";
      return err_msg;
    }
    if (group_about.length > 200 ) {
      String err_msg = "Group description cannot be more than 200 characters.";
      return err_msg;
    }

    if (relays.length > 2000) {
      String err_msg = "Relays list cannot be more than 2000 characters.";
      return err_msg;
    }

    final global_config = GlobalConfig();
    int max_relays = global_config.max_number_relays_fatgroup_create;

    List<String> relay_list = relays.split(",");
    int number_relays = relay_list.length;
    if (number_relays > max_relays) {
      String err_msg = "Maximum number of relays here is "+ max_relays.toString();
      return err_msg;
    }

    String kind40_post = "";
    String kind41_post = "";
    kind40_post = await nostr_core.create_kind40_post(group_name.trim(), group_about.trim());
    String eTagId = OG_util.getIdFromEvent(kind40_post);

    kind41_post = await nostr_core.create_kind41_post(eTagId, relays);

     try {
       // call websocketmanagermulti for posting fatgroup function
     websocketmanagermulti.createFatGroup(kind40_post, kind41_post, relays);
     }
     catch (e) {
       print (e);
     }
 goHome();
    String? retval=null;
    return retval;
  }

  // DB operations to insert the relay.
  Future<String?> attemptToInsertRelay(String relay) async {
    String left_panel_position =
        await OG_HiveInterface.get_Highest_Left_Panel_Position();
    left_panel_position =
        (int.parse(left_panel_position) + 1).toString(); // INCREMENT BY ONE
    try {
      // Attempt to insert the item data here.
      await OG_HiveInterface.addData_Relays(relay, left_panel_position);
      // If successful, return null.
    } catch (e) {
      // If an exception occurs, return the error message as a string.
      return e.toString();
    }
    // Use a scheduleMicrotask to make sure setState is called after the awaited functions finish

    return null;
  }



  void showCreateFatGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String _errorMessage = '';
        TextEditingController _nameController = TextEditingController();
        TextEditingController _aboutController = TextEditingController();
        TextEditingController _relayController = TextEditingController();
        FocusNode _focusNode = FocusNode(); // Create a FocusNode

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> _submitForm() async {
              String? result = await handleCreateFatGroup(
                _nameController.text,
                _aboutController.text,
                _relayController.text,
              );
              if (result == null) {

                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Group Created!'),
                      content: Text('Your new group has been submitted to the relays.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close the info dialog
                          },
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              } else {
                setState(() {
                  _errorMessage = result;
                });
              }
            }

            return AlertDialog(
              title: Text('Create a Group Chat'),
              content: Container(
                width: 400.0,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nameController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          labelText: 'Group Name',
                        ),
                        onSubmitted: (text) => _submitForm(),
                        autofocus: true,
                      ),
                      TextField(
                        controller: _aboutController,
                        decoration: InputDecoration(
                          labelText: 'Group About',
                        ),
                        onSubmitted: (text) => _submitForm(),
                      ),
                      TextField(
                        controller: _relayController,
                        decoration: InputDecoration(
                          labelText: 'Enter List of Relays: (separated by commas)',
                        ),
                        onSubmitted: (text) => _submitForm(),
                      ),
                      if (_errorMessage.isNotEmpty)
                        Text(_errorMessage, style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _submitForm,
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  } // end of showCreateFatGroupDialog


  // Show the dialog to create new relay.
  void showInsertRelayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String _errorMessage = '';
        TextEditingController _itemController = TextEditingController();
        FocusNode _focusNode = FocusNode(); // Create a FocusNode

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> _submitForm() async {
              String? result = await handleInsertRelay(_itemController.text);
              if (result == null) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _errorMessage = result;
                });
              }
            }

            return AlertDialog(
              title: Text('Add a Relay'),
              content: Container(
                width: 400.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _itemController,
                      focusNode: _focusNode,
                      // Assign the FocusNode to the TextField
                      decoration: InputDecoration(
                          labelText:
                              'Enter Relay: (usually begins with wss://)'),
                      onSubmitted: (text) => _submitForm(),
                      autofocus: true, // Set the autofocus property to true
                    ),
                    if (_errorMessage.isNotEmpty)
                      Text(_errorMessage, style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _submitForm,
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  } // Show Insert Relay Dialog

  // Build an overlay, this is the structure for the emoji picker grid.

  Future<void> _buildEmojiPickerOverlay(BuildContext context) async {
    _emojiPickerOverlay = OverlayEntry(
      builder: (BuildContext context) {
        return Stack(
          children: [
            // Add GestureDetector to listen for taps outside of the emoji picker
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  toggleEmojiPicker(); // Call the toggleEmojiPicker function
                },
                // Prevent the GestureDetector from blocking taps on the emoji picker itself
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 76,
              right: 0, // Set right to 0
              child: Container(
                width: 300, // Set a fixed width for the Container
                height: 300, // Set a fixed height for the Container
                child: OG_EmojiPicker(
                  onEmojiSelected: (String emoji) {
                    textEditingController.text += emoji;
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context)?.insert(_emojiPickerOverlay!);
  }


  // PROCESS THE INPUT BAR.
  Future<void> processText(String post_content,
      {String? e_Tag_Reply, String? p_Tag_Reply}) async {

    // If we're in a group chat room...
    if (_roomType == "group") {
      if (websocketmanagermulti.isWebSocketOpen(0) == true) {

        String kind42_post = "";

        // This is the e_tag of the root kind 40, not to be confused with reply e_tag of kind 42.
        String e_tag = _rightPanelUniqueRowId.split(',')[0].trim();

        String reply_e_Tag = "";
        if (e_Tag_Reply != null) {
          reply_e_Tag = e_Tag_Reply;
        }

        String reply_p_Tag = "";
        if (p_Tag_Reply != null) {
          reply_p_Tag = p_Tag_Reply;
        }

        kind42_post = await nostr_core.create_kind42_post(e_tag, post_content,
            e_Tag_Reply: reply_e_Tag, p_Tag_Reply: reply_p_Tag);

        websocketmanagermulti.send(0,kind42_post);
      } else {
        print("WEBSOCKET NOT OPEN!");
      }
    }


    //--------------------------------

    // If we're in a group chat room...
    if (_roomType == "fat_group") {
      List<int> openSocketIds = await websocketmanagermulti.getActiveSockets();
      if (openSocketIds.isNotEmpty) {
        String kind42_post = "";

        // This is the e_tag of the root kind 40, not to be confused with reply e_tag of kind 42.
        String e_tag = _rightPanelUniqueRowId;

        String reply_e_Tag = "";
        if (e_Tag_Reply != null) {
          reply_e_Tag = e_Tag_Reply;
        }

        String reply_p_Tag = "";
        if (p_Tag_Reply != null) {
          reply_p_Tag = p_Tag_Reply;
        }

        kind42_post = await nostr_core.create_kind42_post(e_tag, post_content,
            e_Tag_Reply: reply_e_Tag, p_Tag_Reply: reply_p_Tag);

        // Send message to all open sockets concurrently
        await Future.wait(openSocketIds.map((socketId) => websocketmanagermulti.send(socketId, kind42_post)));


      } else {
        print("NO OPEN WEBSOCKETS!");
      }
    }

    // For a direct message...
    if (_roomType == "friend") {
      if (websocketmanagermulti.isWebSocketOpen(0) == true) {
        //ATTEMPT TO POST
        String kind04_post = "";
        String friend_pubkey = _rightPanelUniqueRowId;
        kind04_post =
            await nostr_core.create_kind04_post(friend_pubkey, post_content);
        websocketmanagermulti.send(0,kind04_post);
      } else {
        print("WEBSOCKET NOT OPEN!");
      }
    }
  } // end function

  // "Home" means we're not in any room, clear out the panels.  This is useful for transition states.
  void goHome() {
    _roomType = "home";
    _rightPanelRoomName = "";
    _rightPanelUniqueRowId = "none";
    _oneTimeRepaintRightPanel = true;
  }

  // The main build function to build the widget tree.
  @override
  Widget build(BuildContext context) {
    if (!_dataReady) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onHorizontalDragStart: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final boundaryTolerance =
            20.0; // Set this value to the desired tolerance in pixels

        if ((details.globalPosition.dx >
                screenWidth * _leftSectionWidth - boundaryTolerance) &&
            (details.globalPosition.dx <
                screenWidth * _leftSectionWidth + boundaryTolerance)) {
          _dragStartPosition = details.globalPosition.dx;
          _dragging = true;
        } else {
          _dragging = false;
        }
      },
      onHorizontalDragUpdate: (details) {
        if (_dragging) {
          final screenWidth = MediaQuery.of(context).size.width;
          final minWidthPercentage = 270 / screenWidth;
          final dragDistance = details.globalPosition.dx - _dragStartPosition;
          final dragPercentage = dragDistance / screenWidth;

          setState(() {
            _leftSectionWidth += dragPercentage;
            if (_leftSectionWidth < minWidthPercentage) {
              _leftSectionWidth = minWidthPercentage;
            } else if (_leftSectionWidth > 0.9) {
              _leftSectionWidth = 0.9;
            }
          });
          _dragStartPosition += dragDistance;
        }
      },
      child: Scaffold(
        drawer: Drawer(
          child: Container(
            color: Color(0xFFCCCCCC),
            child: ListView(
              children: [
                InkWell(
                  onTap: () {
                    goHome();
                    if (_emojiPickerVisible) {
                      toggleEmojiPicker();
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AliasScreen()),
                    );
                  },
                  child: ListTile(
                    title: Text(
                      'Manage my IDs',
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),

                ),
                InkWell(
                  onTap: () {
                    if (_emojiPickerVisible) {
                      toggleEmojiPicker();
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                  },
                  child: ListTile(
                    title: Text('Settings',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.deepPurple,
                        )
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (_emojiPickerVisible) {
                      toggleEmojiPicker();
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              AboutScreen()),
                    );
                  },
                  child: ListTile(
                    title: Text('About',
                        style: TextStyle(
                          fontSize: 18.0,
                          color: Colors.deepPurple,

                        )
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double screenWidth = constraints.maxWidth;
            final double minWidth = 250;
            final double leftSectionWidth =
                max(minWidth, _leftSectionWidth * screenWidth);

            return Row(
              children: [
                Container(
                  width: leftSectionWidth,
                  //color: Colors.blueGrey[100],
                  color: Colors.white30,
                  child: Builder(builder: (BuildContext context) {
                    return Column(
                      children: [
                        Expanded(
                          child: ListView(children: _cachedRowItems),
                        ),
                        Container(
                          height: 130.0,
                          padding: EdgeInsets.all(8.0),
                          color: Color(0xFFF8F8F8),
                          child: Column(
                            children: [
                              Divider(
                                thickness: 2.0,
                                color: Colors.blueGrey,
                                indent: 8.0,
                                endIndent: 8.0,
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Tooltip(
                                      message: 'Add a relay.',
                                      child: InkWell(
                                        onTap: () {
                                          showInsertRelayDialog(context);
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: Colors.blue,
                                          radius: 20.0,
                                          child: Icon(Icons.add,
                                              size: 30.0, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.0),
                                    Tooltip(
                                      message: 'Add a contact.',
                                      child: InkWell(
                                        onTap: () {
                                          showAvatarSelectionDialog(context);
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: Colors.redAccent,
                                          radius: 20.0,
                                          child: Icon(Icons.add,
                                              size: 30.0, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.0),
                                    Tooltip(
                                      message: 'Create a Group Chat',
                                      child: InkWell(
                                        onTap: () {
                                          showCreateFatGroupDialog(context);
                                          setState(() {
                                            _shouldUpdateRowCache = true;
                                          });
                                          _fetchAndUpdateRowCache()
                                              .then((_) => () {});
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black,
                                          radius: 20.0,
                                          child: Icon(Icons.add,
                                              size: 30.0, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.0),
                                    Tooltip(
                                      message: 'Sort by name or time.',
                                      child: InkWell(
                                        onTap: () {
                                          toggleLeftPaneSortStyle();
                                          setState(() {
                                            _shouldUpdateRowCache = true;
                                          });
                                          _fetchAndUpdateRowCache()
                                              .then((_) => () {});
                                        },
                                        child: CircleAvatar(
                                          backgroundColor: Colors.grey,
                                          radius: 20.0,
                                          child: Icon(Icons.sort,
                                              size: 24.0, color: Colors.black),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 110,
                        // Set the desired height for the top container
                        color: Color(0xFFF8F8F8),
                        // Set the desired background color for the top container
                        child: TopContainer(splitScreenState: this),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(wallPaperString),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              // Handle the tap event here, e.g., close the reply widget
                              // turn off emoji flag
                             isEmojiPickerActive.value = false;
                              // Close the reply widget
                             updateShowReplyWidget(false);
                            },
                            child: RightPanel(
                              cachedItemsNotifier: _RightPanelNotifier,
                              shouldRequestFocus: shouldRightPanelRequestFocus,
                            ),
                          ),
                        ),
                      ),

                      InputBarContainer(
                        key: _inputBarKey,
                        splitScreenState: this,
                        updateReplyWidgetItems: () =>
                            ui_helper.getReplyWidgetItems(
                          replyMessageText,
                          replyDisplayName,
                          replyDisplayNameColor,
                        ),
                        isEmojiPickerActive: isEmojiPickerActive
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

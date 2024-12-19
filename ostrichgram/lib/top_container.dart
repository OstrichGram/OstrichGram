import 'package:flutter/material.dart';
import 'web_socket_manager_multi.dart';
import 'dart:async';
import 'og_hive_interface.dart';
import 'main.dart';
import 'nostr_core.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ui_helper.dart';
import 'global_config.dart';

/*

Top container runs on a 3 second loop and attempts to keep the top part updated in terms of
the room type on the left and its image, the middle part which has the current chosen Alias,
and the right side which contains the current relay of the room along with its status.

The updates for the connection status are a little bit tricky.  We keep checking the websocket
manager to know the status of the connection and try to update it along with the animated icon.
There's also a "processing status" which is useful if signature checking is taking a long time.
And also, the user can manually reload the top container which also reconnects and send the
query to the relay.

 */

class DataFromDB {
  final List<String> dataList;
  final Widget friendAvatar;

  DataFromDB({required this.dataList, required this.friendAvatar});
}


class TopContainer extends StatefulWidget {
  final SplitScreenState splitScreenState;

  TopContainer({required this.splitScreenState});

  @override
  _TopContainerState createState() => _TopContainerState();
}

class _TopContainerState extends State<TopContainer>
    with SingleTickerProviderStateMixin {
  WebSocketManagerMulti _webSocketManagerMulti = WebSocketManagerMulti();
  ValueNotifier<int> _isConnected = ValueNotifier(0);
  String _topcontainer_relay = "";

  String userAvatarImage = "assets/images/OS-1-nb.png";

  late AnimationController _rotationController;
  String customOstrich = "";
  String _currentAliasPubkey = "";
  String friend_pubkey = "";
  String _roomDescription = "";
  String _roomDescriptionLabel = "";
  bool _isManualReload = false;
 String multiRelaySocketDescription="";



  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    widget.splitScreenState.processingWebSocketInfo.addListener(_processingWebSocketInfoChanged);

    _checkWebSocketConnectionPeriodically();
  }

  @override
  void dispose() {
    _isConnected.dispose();
    super.dispose();
  }

  void _processingWebSocketInfoChanged() {
    bool processingStatus = widget.splitScreenState.processingWebSocketInfo.value;

    if (processingStatus == true) {
      _rotationController.repeat();
      setState(() {
        _isConnected.value = 2;
      });
    }
    if (processingStatus == false) {
      int old_isConnected_Val = _isConnected.value;
      if (!_isManualReload) {
        _rotationController.stop();
      }
        if (old_isConnected_Val != _isConnected.value) {
          setState(() {
            ;
          });

        }


    }
  }



  void closeWebSocketConnection() {
    _webSocketManagerMulti.closeAllWebSocketConnections();
  }

  Future<void> copyAliasNpubToClipboard() async {
    String my_npub = "";

    DataFromDB myFreshData = await _getDataFromDB();

    my_npub = myFreshData.dataList[2];

    await Clipboard.setData(ClipboardData(text: my_npub));
  }


  void reload() {
    _isManualReload = true;
    _rotationController.forward(from: 0.0); // Start the rotation animation

    Future.delayed(Duration(seconds: 2)).then((_) {
      setState(() {
        _isManualReload = false;
        reload_top();
      });
    });
  }



  void _checkWebSocketConnectionPeriodically() async {
    try {
      Timer.periodic(Duration(seconds: 3), (timer) async {
        // SET THE VALUE ONLY THE FIRST TIME WHEN _topcontainer_relay is empty.
        // This way the first non empty value persists.  Refresh should then
        // be guaranteed to have right value and this only changes if screen is reloaded.

        Map<String, String> chosenAliasData = await OG_HiveInterface.getData_Chosen_Alias_Map();
        String alias_pubkey ="";
        String alias_name = chosenAliasData?['alias'] ?? '';

        if (alias_name != null) {

          Map<String, dynamic> aliasMap2 =await OG_HiveInterface.getData_AliasMapFromName(alias_name);
          alias_pubkey= aliasMap2['pubkey'] ?? '';
        }

        if (widget.splitScreenState.rightPanelRoomName != _roomDescription) {
          setState(() {

          });
        } else if (_currentAliasPubkey != alias_pubkey ) {
          _currentAliasPubkey = alias_pubkey;
          setState(() {
          });
        }

        // Right now fat group is the only thing useing multirelay. everything else, just use socket 0.
        if (widget.splitScreenState.roomType == "fat_group") {
          _topcontainer_relay = "multi-relay";
        }
        else {
          _topcontainer_relay = _webSocketManagerMulti.getUri(0);
        }

        try {
          if (widget.splitScreenState.roomType == "fat_group") {

            String socketLabel="";


            String original_relays="";
            String e_tag = widget.splitScreenState.rightPanelUniqueRowId;
            Map<String,dynamic> fatGroupMap = await OG_HiveInterface.getData_FatGroupMap(e_tag);
            if ( fatGroupMap['metadata_relays'] != null) {
              original_relays = fatGroupMap['metadata_relays'];
            }

            int original_number_relays = original_relays.split(",").length;
            List<int> currentSocketIds = await _webSocketManagerMulti.getActiveSockets();

            if (currentSocketIds.length > 0 ) {
              socketLabel = "Connected: (" + currentSocketIds.length.toString() + "/" + original_number_relays.toString() + ")";
              _isConnected.value = 4; // let 4 mean to use multirelayscoketdescription connected.
              multiRelaySocketDescription = socketLabel;
            } else {
              // Disconnected.
              socketLabel = "Offline: (0/"+original_number_relays.toString()+")";
              _isConnected.value = 5; // let 4 mean to use multirelayscoketdescription DISCONNECTED.
              multiRelaySocketDescription = socketLabel;
            }



          }

          else {
            bool socketState = _webSocketManagerMulti.isWebSocketOpen(0);
            if (socketState) {
              _isConnected.value = 1;
            } else {
              _isConnected.value = 0;
            }
          }


        } catch (e) {
          print('Error: $e');
        }
      });
    } catch (e, s) {
      print(s);
    }
  }

  void clear_cache() async {

    String my_unique_id =  widget.splitScreenState.rightPanelUniqueRowId;
    String my_room_type = widget.splitScreenState.roomType;

    switch (my_room_type) {
      case 'relay':
        await OG_HiveInterface.removeMessagesForRelay(_topcontainer_relay);
        reload();
        break;
      case 'friend':
        String composite_key = my_unique_id +"_"+ _currentAliasPubkey;
        await OG_HiveInterface.removeMessagesForFriend(composite_key);
        reload();
        break;
      case 'group':
        await OG_HiveInterface.removeMessagesForGroup(my_unique_id);
        await OG_HiveInterface.updateOrInsert_MessagesGroupCacheWatermark(my_unique_id,0);
        reload();
        break;
      case 'fat_group':
        await OG_HiveInterface.removeMessagesForFatGroup(my_unique_id);
        await OG_HiveInterface.dumpCacheFatGroupWatermark(my_unique_id);
        reload();
    }
  }

  void reload_top() async {


    WebSocketManagerMulti websocketmanagermulti = WebSocketManagerMulti();

      websocketmanagermulti.closeAllWebSocketConnections();
      Future.delayed(Duration(milliseconds: 50)).then((_) {
      });


    if (widget.splitScreenState.roomType == "relay"){

      String requestKind40s = nostr_core.constructJSON_fetch_kind_40s();

      String requestKind41s = nostr_core.constructJSON_fetch_kind_41s();
      try { await widget.splitScreenState.freshWebSocketConnectandSend(_topcontainer_relay, requestKind40s,secondary_message:  requestKind41s);
      }
      catch (e) {
      }
    }

    if (widget.splitScreenState.roomType == "group"){


      final globalConfig = GlobalConfig();
      int numberItemsToFetch=globalConfig.message_limit;

      String e_tag = widget.splitScreenState.rightPanelUniqueRowId.split(',')[0];
      String requestKind42s = nostr_core.constructJSON_fetch_kind_42s(e_tag,numberItemsToFetch);
      try { await widget.splitScreenState.freshWebSocketConnectandSend(_topcontainer_relay, requestKind42s);
      }
      catch (e) {
      }
    }

    if (widget.splitScreenState.roomType == "fat_group"){

      websocketmanagermulti.closeAllWebSocketConnections();

      final globalConfig = GlobalConfig();
      int numberItemsToFetch=globalConfig.message_limit;

      String e_tag = widget.splitScreenState.rightPanelUniqueRowId;
      String requestKind42s = nostr_core.constructJSON_fetch_kind_42s(e_tag,numberItemsToFetch);

      try {

        Map<String,dynamic> fatGroupMap = await OG_HiveInterface.getData_FatGroupMap(e_tag);

        String relays="";

        if ( fatGroupMap['metadata_relays'] != null) {
          relays = fatGroupMap['metadata_relays'];
        }

         await widget.splitScreenState.freshWebSocketConnectandSend(relays, requestKind42s,multiSend: true);
      }
      catch (e) {
      }
    }


    if (widget.splitScreenState.roomType == "friend"){


      String requestKind04s_TOUSER = nostr_core.constructJSON_fetch_kind_04s(friend_pubkey,_currentAliasPubkey);

      String requestKind04s_FROMUSER = nostr_core.constructJSON_fetch_kind_04s(_currentAliasPubkey,friend_pubkey);

      try { await widget.splitScreenState.freshWebSocketConnectandSend(_topcontainer_relay, requestKind04s_TOUSER, secondary_message: requestKind04s_FROMUSER);
      } catch (e) {
        print ('something went wrong trying to call freshWebSocketConnectandSend.');
        print (e);
      }


    }


  } //end reload top

  Future<Widget> createEmptySvgPicture() async {
    String emptySvgString =
        '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60"></svg>';
    // Return an SvgPicture as a placeholder
    return SvgPicture.string(
      emptySvgString,
      width: 60,
      height: 60,
    );
  }

  static Widget buildTopFriendImage(
      BuildContext context, String friend_pubkey) {
    return FutureBuilder<Widget>(
      future: ui_helper.generateAvatar(friend_pubkey, blackAndWhite: false),
      builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return SizedBox(
            width: 60,
            height: 60,
            child: snapshot.data,
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else {
          return SizedBox(
            width: 60,
            height: 60,
            child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60"></svg>',
            ),
          );
        }
      },
    );
  }




  Future<DataFromDB> _getDataFromDB() async {

    // Define this first for the case of a new user and we have to return early.
    String relay_name = _webSocketManagerMulti.getUri(0) ?? '';

    Map<String, String> chosenAliasData =
        await OG_HiveInterface.getData_Chosen_Alias_Map();
    String alias_name = chosenAliasData?['alias'] ?? '';


    if (alias_name == null || alias_name == "") {
      return DataFromDB(
          dataList: [" ", relay_name, " "],
          friendAvatar: await createEmptySvgPicture());

    }

    Map<String, dynamic> aliasMap2 =
        await OG_HiveInterface.getData_AliasMapFromName(alias_name);

    customOstrich = "";
    customOstrich = aliasMap2['customOstrich'] ?? '';
    _currentAliasPubkey = aliasMap2['pubkey'] ?? '';
    if (customOstrich == null) {
      customOstrich = "1";
    } else if (customOstrich == "") {
      customOstrich = "1";
    }
    String npub = "";
    if (_currentAliasPubkey != null) {
      try {
        npub = (nostr_core.hexToBech32(_currentAliasPubkey, "npub"));
      } catch (e) {
        print(e);
        return DataFromDB(
            dataList: [" ", relay_name, " "],
            friendAvatar: await createEmptySvgPicture());
      }
    }

    final String alias_npub = npub;
    String alias_display_name =
        alias_name + "  " + npub.substring(0, 12) + "...";
    if (alias_display_name.length > 35) {
      alias_display_name = alias_display_name.substring(0, 33);
      alias_display_name = alias_display_name + "...";
    }

    userAvatarImage = "assets/images/OS-" + customOstrich + "-nb.png";
    // Replace this with your actual database call for the relay name


    if (relay_name.length > 26) {
      relay_name = relay_name.substring(0, 26);
      relay_name = relay_name + "...";
    }

    if (widget.splitScreenState.roomType == "fat_group")
      {
       relay_name = "multi-relay";

      }  else {
      if (relay_name.trim() == "") {
        relay_name = "Not connected to a relay.";
      }
    }

    // Instantiate an empty SvgPicture widget
    Widget friendAvatar = await createEmptySvgPicture();


    if (widget.splitScreenState.roomType == "friend") {
      friend_pubkey = widget.splitScreenState.rightPanelUniqueRowId;

      String avatar_style = "01";
      try {
        Map<String, dynamic> friendMap =
            await OG_HiveInterface.getData_FriendMapFromPubkey(friend_pubkey);

        avatar_style = friendMap['avatar_style'];
      } catch (e) {
        print(
            "There was a problem generating an avatar image. Using a fallback theme override.");
      }
      friendAvatar = await ui_helper.generateAvatar(friend_pubkey,
          blackAndWhite: false, themeOverride: avatar_style);
    }

    return DataFromDB(
        dataList: [alias_display_name, relay_name, alias_npub],
        friendAvatar: friendAvatar);
  }  // END data from db

  @override
  Widget build(BuildContext context) {
    String rightPanelRoomName = widget.splitScreenState.rightPanelRoomName;
    String roomType = widget.splitScreenState.roomType;
    String roomTypeDesc = "";
    String roomImageString = "assets/images/empty.png";


if (_isConnected.value ==2 ) {
  _rotationController.repeat();
}

    if (roomType.trim().length > 0) {
      if (roomType == "friend") {
        roomImageString = "";
        roomTypeDesc = "Chat with ";
      }
      if (roomType == "relay") {
        roomTypeDesc = "Browsing: ";
        roomImageString = "assets/images/orb1-60.png";
      }
      if (roomType == "group") {
        roomTypeDesc = "group: ";

        roomImageString = "assets/images/GROUP3.png";
      }

      if (roomType == "fat_group") {
        roomTypeDesc = "Group: ";

        roomImageString = "assets/images/FATGROUP.png";
      }

      _roomDescriptionLabel = roomTypeDesc + rightPanelRoomName;
      _roomDescription = rightPanelRoomName;
    }

// Create a ScrollController
    final _scrollController = ScrollController();


    return FutureBuilder<DataFromDB>(
      future: _getDataFromDB(),
      builder: (BuildContext context, AsyncSnapshot<DataFromDB> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          String alias_name = snapshot.data?.dataList[0] ?? '';
          String relay_name = snapshot.data?.dataList[1] ?? '';
          Widget friendAvatar = snapshot.data?.friendAvatar ?? SvgPicture.string(
            '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60"></svg>',
            width: 60,
            height: 60,
          );

          return Container(
            height: 110,
            color: Color(0xFFF8F8F8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // set to spaceBetween
              children: [
                //LEFT PART OF TOP ROW

                Flexible(
                  flex: 2,
                  child: Container(
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              SizedBox(width: 12),
                          roomType == "friend"
                              ? SizedBox(
                              width: 60,
                              height: 60,
                            child: friendAvatar,
                        )
                            : Image.asset(
                          roomImageString,
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ],

                    ),
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _roomDescriptionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // MIDDLE PART OF TOP ROW:

                // MIDDLE PART OF TOP ROW:
                Flexible(
                  flex: 2,
                  child: GestureDetector(
                    onSecondaryTapDown: (details) {
                      // Show the context menu
                      showMenu(
                        context: context,
                        position: RelativeRect.fromRect(
                            details.globalPosition & Size(40, 40),
                            Offset.zero & MediaQuery.of(context).size),
                        items: [
                          PopupMenuItem(
                            value: 'copy_npub',
                            child: Text('Copy npub'),
                          ),
                        ],
                      ).then((value) {
                        if (value == 'copy_npub') {
                          copyAliasNpubToClipboard();
                        }
                      });
                    },
                    child: Tooltip(
                      message: "Your ID",
                      child: Container(
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Center(
                                    child: RepaintBoundary(
                                      child: Image.asset(
                                        userAvatarImage,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 0),
                                ],
                              ),
                            ),
                            // Second Row Widget
                            SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    alias_name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                      fontSize: 16,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

// RIGHT THIRD OF ROW
                Flexible(
                  flex: 2,
                  child: Container(
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // First Row Widget
                          Container(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ValueListenableBuilder<int>(
                                  valueListenable: _isConnected,
                                  builder: (BuildContext context, int isConnectedValue, Widget? child) {
                                    return Flexible(
                                      child: Text(
                                        isConnectedValue == 0
                                            ? 'Status: Offline'
                                            : isConnectedValue == 1
                                            ? 'Status: Connected'
                                            : isConnectedValue == 2
                                            ? 'Status: Processing'
                                            : multiRelaySocketDescription,
                                        style: TextStyle(
                                          color: isConnectedValue == 0
                                              ? Colors.red
                                              : isConnectedValue == 1
                                              ? Colors.green
                                              : isConnectedValue == 2
                                              ? Colors.blue
                                              : isConnectedValue == 4
                                              ? Colors.green
                                              : isConnectedValue == 5
                                              ? Colors.red
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          overflow: TextOverflow.ellipsis,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(width: 12),
                              ],
                            ),
                          ),
                          // Second Row Widget
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  relay_name,
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                            ],
                          ),
                          // Third Row Widget
                          SizedBox(height: 6),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  clear_cache();
                                },
                                child: Tooltip(
                                  message: 'Clear Cache',
                                  child: Icon(
                                    Icons.delete_sweep,  // Icon for clearing cache
                                    size: 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: reload,
                                child: AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationController.value * 2 * math.pi,
                                      child: Tooltip(
                                        message: 'Reconnect and resend query',
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.refresh,
                                    size: 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
// END RIGHT THIRD
              ],
            ),
          );
        }
      },
    );
  }
}

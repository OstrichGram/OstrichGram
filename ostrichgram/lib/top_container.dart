import 'package:flutter/material.dart';
import 'package:flutter_svg/parser.dart';
import 'web_socket_manager_multi.dart';
import 'dart:async';
import 'og_hive_interface.dart';
import 'main.dart';
import 'nostr_core.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ui_helper.dart';
import 'my_paint.dart';
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
  final DrawableRoot friendAvatar;

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
    _webSocketManagerMulti.closeWebSocketConnection(0);
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

          _topcontainer_relay = _webSocketManagerMulti.getUri(0);

        try {


          bool socketState = _webSocketManagerMulti.isWebSocketOpen(0);
          if (socketState) {
            _isConnected.value = 1;
          } else {
            _isConnected.value = 0;
          }



        } catch (e) {
          print('Error: $e');
        }
      });
    } catch (e, s) {
      print(s);
    }
  }

  void reload_top() async {


    WebSocketManagerMulti websocketmanagermulti = WebSocketManagerMulti();

    if (websocketmanagermulti.isWebSocketOpen(0)) {
      websocketmanagermulti.closeWebSocketConnection(0);
      Future.delayed(Duration(milliseconds: 50)).then((_) {
      });

    }

    if (widget.splitScreenState.roomType == "relay"){

      String requestKind40s = nostr_core.constructJSON_fetch_kind_40s();
      try { await widget.splitScreenState.freshWebSocketConnectandSend(_topcontainer_relay, requestKind40s);
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



  Future<DrawableRoot> createEmptyDrawableRoot() async {
    SvgParser myParser = SvgParser();
    String emptySvgString =
        '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0"></svg>';
    return await myParser.parse(emptySvgString);
  }

  static Widget buildTopFriendImage(
      BuildContext context, String friend_pubkey) {
    return FutureBuilder(
      future: ui_helper.generateAvatar(friend_pubkey, blackAndWhite: false),
      builder: (BuildContext context, AsyncSnapshot<DrawableRoot?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CustomPaint(
            painter: MyPainter60(snapshot.data!, Size(60, 60)),
            size: Size(60, 60),
          );
        } else {
          return CircularProgressIndicator();
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
          dataList: [" ", relay_name, " "],      //!!!
          friendAvatar: await createEmptyDrawableRoot());
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
            friendAvatar: await createEmptyDrawableRoot());
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

    if (relay_name.trim() == "") {
      relay_name = "Not connected to a relay.";
    }

// Instantiate an empty DrawableRoot object
    DrawableRoot friendAvatar = await createEmptyDrawableRoot();


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
        roomTypeDesc = "Group: ";

        roomImageString = "assets/images/GROUP3.png";
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
          DrawableRoot? friendAvatar = snapshot.data?.friendAvatar;
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
                                  ? CustomPaint(
                                      painter: MyPainter60(
                                          (friendAvatar ??
                                                  createEmptyDrawableRoot())
                                              as DrawableRoot,
                                          Size(60, 60)),
                                      size: Size(60, 60),
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
                                            : 'Unknown Status',
                                        style: TextStyle(
                                          color: isConnectedValue == 0
                                              ? Colors.red
                                              : isConnectedValue == 1
                                              ? Colors.green
                                              : isConnectedValue == 2
                                              ? Colors.blue
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
                                onTap: reload,
                                child: AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationController.value *
                                          2 *
                                          math.pi,
                                      child: child,
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

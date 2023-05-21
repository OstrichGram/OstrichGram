import 'ui_helper.dart';
import 'package:flutter/material.dart';

// Helper class to render widgets for the right screen.

class render {
  static Future<List<Widget>> fetchDataAndRenderWidgets(
      List<Map<String, String>> formattedData,
      BuildContext context,
      Function onMainCallback,
      String relay,
      String roomType,
      String room_id) async {

    //List<Widget>
    List<Widget> freshWidgets;


    switch (roomType) {
      case "group":
        freshWidgets = await ui_helper.getAllChatItemsGroup(
            context, onMainCallback, room_id, formattedData);
        break;
      case "fat_group":
        freshWidgets = await ui_helper.getAllChatItemsGroup(
            context, onMainCallback, room_id, formattedData);
        break;
      case "friend":
        //room_id here is the friends pubkey.
        freshWidgets = await ui_helper.getAllChatItemsFriend(context, onMainCallback, room_id, formattedData);
        break;
      case "relay":
        freshWidgets = await ui_helper.getAllChatItemsRelay(
            context, onMainCallback, room_id, formattedData);
        break;
      default:
        freshWidgets = ui_helper.errorBubble("BAD ROOM TYPE in render.dart", roomType);
    }

    return freshWidgets;
  }
}

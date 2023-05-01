import 'package:flutter/material.dart';
import 'nostr_core.dart';
import 'web_socket_manager.dart';
import 'package:flutter/services.dart';
import 'main.dart';

class InputBarContainer extends StatefulWidget {
  final GlobalKey<InputBarState> key;
  final SplitScreenState splitScreenState;
  final Function updateReplyWidgetItems;
  final ValueNotifier<bool> isEmojiPickerActive;

  InputBarContainer({required this.key, required this.splitScreenState, required this.updateReplyWidgetItems,required this.isEmojiPickerActive, }) : super(key: key);

  @override
  InputBarState createState() => InputBarState();

  void requestFocus() {
    key.currentState?.requestFocus();
  }
}


class InputBarState extends State<InputBarContainer> {
  FocusNode _focusNode = FocusNode();
  WebSocketManager webSocketManager = WebSocketManager();

  int inputBarDisplayType = 1;  // 1 = Show the normal bar.   // 2 = Show add group button //3 = nothing

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);



  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  void _handleFocusChange() {

  }
  /*

// This code was too finicky and unreliable.  The idea was close the reply widget for any non-focus but
// the focus was too easy to "steal".  Instead, we will simply listen for right pane clicks in the main
// widget tree and close the reply widget if that happens.

  // if the user clicks away from reply , reset everything
  void _handleFocusChange() {
    Future.delayed(Duration(milliseconds: 100), () { //delay for emoji picker to send signal its open and dont close the widget
      // If the reply widget loses focus, do the following:
      if (!_focusNode.hasFocus && !widget.isEmojiPickerActive.value) {
        widget.splitScreenState.updateShowReplyWidget(
            false); // close the widget
        widget.splitScreenState
            .regainMainWindowFocus(); // give focus back to main window
        widget.splitScreenState.eTagReply =
        ""; // reset the e and p tags to empty so they don't make the next message appear as a quote even if the reply widget is closed !
        widget.splitScreenState.pTagReply = "";
      }
    });
  }


   */


  Future<String?> handleCreateNewGroup(String name, String about) async {

    if (name.trim() == "" ) {
      return "Group name cannot be empty.";
    }
    if (name.length > 50) {
      return "Group name cannot be larger than 50 characters.";
    }

    if (about.length > 150) {
      return "Group description cannot be larger than 150 characters.";
    }

    String kind40_post = "";
    kind40_post = await nostr_core.create_kind40_post(name.trim(), about.trim());

    webSocketManager.send(kind40_post);

    return null;
  }

  void showCreateNewGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String _errorMessage = '';
        TextEditingController _nameController = TextEditingController();
        TextEditingController _aboutController = TextEditingController();
        FocusNode _nameFocusNode = FocusNode();
        FocusNode _aboutFocusNode = FocusNode();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> _submitForm() async {
              String? result =
              await handleCreateNewGroup(_nameController.text, _aboutController.text);
              if (result == null) {
                Navigator.of(context).pop(); // Close the current dialog

                // Show a new dialog with a "Submitted!" message
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Group Created!'),
                      content: Text('Your new group has been submitted to the relay.'),
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
              title: Text('Create a New Chat Group'),
              content: Container(
                width: 400.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: InputDecoration(
                          labelText: 'Enter the Group Name'),
                      onSubmitted: (text) => _submitForm(),
                      autofocus: true,
                    ),
                    TextField(
                      controller: _aboutController,
                      focusNode: _aboutFocusNode,
                      decoration:
                      InputDecoration(labelText: 'Enter Group About Info'),
                      onSubmitted: (text) => _submitForm(),
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
  } // showCreateNewGroupDialog



  @override
  Widget build(BuildContext context) {


    // Clear the e and p tags whenever we rebuild the input bar and the reply widget is off.
    if (!widget.splitScreenState.showReplyWidget) {
      widget.splitScreenState.eTagReply = "";
      widget.splitScreenState.pTagReply = "";
    }

    if (widget.splitScreenState.roomType =="relay") {
      inputBarDisplayType = 2;
    }

    if (widget.splitScreenState.roomType =="group") {
      inputBarDisplayType = 1;
    }

    if (widget.splitScreenState.roomType =="friend") {
      inputBarDisplayType = 1;
    }
    if (widget.splitScreenState.roomType =="home" || widget.splitScreenState.roomType =="home_done" ) {
      inputBarDisplayType = 3;
    }

    return Container(
      height: widget.splitScreenState.showReplyWidget ? 76 + 60 : 76,
      color: Color(0xFFF8F8F8),
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Column(
            children: [
              if (inputBarDisplayType == 1)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            if (widget.splitScreenState.showReplyWidget)
                              LimitedBox(
                                maxHeight: 60, // Limit the height of the reply widget to 76
                                child: widget.updateReplyWidgetItems(), // Use the function to create the reply widget items
                              ),
                            SizedBox(height: 12),
                            TextField(
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Open Sans',
                                fontFamilyFallback: ['NotoColorEmoji'],
                              ),
                              focusNode: _focusNode,
                              controller: widget.splitScreenState.textEditingController,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(300),
                              ],
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Write a message...',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),

                              onSubmitted: (text) {
                                widget.splitScreenState.processText(
                                  text,
                                  e_Tag_Reply: widget.splitScreenState.eTagReply,
                                  p_Tag_Reply: widget.splitScreenState.pTagReply,
                                );
                                widget.splitScreenState.textEditingController.clear();

                                // turn off the emojipicker status for this
                                widget.splitScreenState.isEmojiPickerActive.value = false;

                                // Close the reply widget
                                widget.splitScreenState.updateShowReplyWidget(false);

                                // Close the Emoji Picker and update its state
                                if (widget.splitScreenState.isEmojiPickerActive.value) {
                                  widget.splitScreenState.toggleEmojiPicker();
                                }

                                // Request focus for the main input field
                                widget.splitScreenState.shouldRightPanelRequestFocus.value = true;
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 15),
                      InkWell(
                        onTap: widget.splitScreenState.toggleEmojiPicker,
                        child: Icon(Icons.emoji_emotions_outlined, size: 32, color: Colors.blueGrey),
                      ),
                      SizedBox(width: 15),
                      InkWell(
                        onTap: () {
                          String text = widget.splitScreenState.textEditingController.text;
                          if (text.trim().isNotEmpty) {
                            widget.splitScreenState.processText(
                              text,
                              e_Tag_Reply: widget.splitScreenState.eTagReply,
                              p_Tag_Reply: widget.splitScreenState.pTagReply,
                            );
                            widget.splitScreenState.eTagReply = null;
                            widget.splitScreenState.pTagReply = null;
                            widget.splitScreenState.textEditingController.clear();
                            widget.splitScreenState.isEmojiPickerActive.value = false;
                            // Close the reply widget
                            widget.splitScreenState.updateShowReplyWidget(false);
                          }
                        },
                        child: Icon(Icons.send, size: 32, color: Color(0xFF9D58FF)),
                      ),

                      SizedBox(width: 15),
                    ],
                  ),
                ),
              if (inputBarDisplayType == 2)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible( // Wrap the Text widget with Flexible to avoid overflow issues
                            child: Text(
                              "Right-click on a chat group to add to your list, or left-click to add and open.",
                              style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                                fontSize: 16,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          SizedBox(width: 100), // Add some space between the Text and the Icon
                          GestureDetector(
                            onTap: () {
                              showCreateNewGroupDialog(context);
                            },
                            child: Tooltip(
                              message: 'Create a new group on this server.',
                              child: CircleAvatar(
                                backgroundColor: Color(0xFF9D58FF),
                                radius: 12.0,
                                child: Icon(Icons.add, size: 18.0, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (inputBarDisplayType == 3)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible( // Wrap the Text widget with Flexible to avoid overflow issues
                            child: Text(
                              " ",
                              style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
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
            ],
          ),
        ),
      ),
    );
  }
}
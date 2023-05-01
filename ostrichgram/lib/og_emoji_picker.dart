import 'package:flutter/material.dart';

// This class creates a basic 10x10 grid emoji picker widget.  This is called by the
// Emoji picker overlay in the main.dart widget tree.

class OG_EmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const OG_EmojiPicker({Key? key, required this.onEmojiSelected}) : super(key: key);

  @override
  _OG_EmojiPickerState createState() => _OG_EmojiPickerState();
}

class _OG_EmojiPickerState extends State<OG_EmojiPicker> {
  Widget _buildEmojiGrid() {
    int emojiCount = 100; // 10x10 grid



  List<String> emojis = [
  '👍', '👎', '👌', '👋', '👐', '💪', '🤞', '🤟', '🙏', '🤝',
  '😂', '😁', '🤣', '😭', '😘', '😍', '😊', '😁', '🤢', '😅',
  '🔥', '☺️', '🤦', '♥️', '🤷', '🙄', '😆', '🤗', '😉', '🤔',
  '💰', '🙂', '😳', '🥳', '😎', '😔', '👀', '😋', '🤠', '🎯',
  '👨‍💼', '👩‍💼', '😩', '💯', '😃', '😡', '💐', '😜', '😄', '🤤',
  '🤪', '😀', '💋', '💀', '😌', '🤩', '😬', '😱', '😴', '🤭',
  '😐', '😒', '😇', '🎶', '🎊', '🥵', '😞', '☀️', '🤡', '😚',
  '😠', '💥', '🤖', '☹️', '😑', '🥴', '🤮', '✅', '💥', '🤑',
  '🍔', '🍟', '🍕', '🌭', '🍗', '🌮', '🥪', '🍣', '🍩', '☕',
  '🚗', '🚕', '🚙', '🚚', '🚲', '🐍', '🐱', '🐔', '🐙', '🦎'
];




    return GridView.builder(
      itemCount: emojiCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
      ),
      itemBuilder: (BuildContext context, int index) {
        String currentEmoji = emojis[index];
        return GestureDetector(
          onTap: () => widget.onEmojiSelected(currentEmoji),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              currentEmoji,
              style: TextStyle(
                fontSize: 18,
                decoration: TextDecoration.none,
                fontFamily: 'NotoColorEmoji',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      child: Material(
        child: _buildEmojiGrid(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:emojis/emoji.dart';

// Incomplete and depecreated implementation of an emoji picker with tabs.  Not used but good reference to created tabs in the emjoi picker in the future.

class OG_EmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const OG_EmojiPicker({Key? key, required this.onEmojiSelected}) : super(key: key);

  @override
  _OG_EmojiPickerState createState() => _OG_EmojiPickerState();
}

class _OG_EmojiPickerState extends State<OG_EmojiPicker> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  List<EmojiGroup> _emojiGroups = [
    EmojiGroup.smileysEmotion,
    EmojiGroup.activities,
    EmojiGroup.peopleBody,
    EmojiGroup.objects,
    EmojiGroup.travelPlaces,
    EmojiGroup.animalsNature,
    EmojiGroup.foodDrink,
    EmojiGroup.symbols
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _emojiGroups.length);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Widget _buildEmojiGrid(EmojiGroup group) {
    List<Emoji> emojis = Emoji.byGroup(group).toList();


    if (group == EmojiGroup.peopleBody) {
      emojis.sort(customSort);
    }

    return GridView.builder(
      itemCount: emojis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
      ),
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () => widget.onEmojiSelected(emojis[index].char),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              emojis[index].char,
              style: TextStyle(
                fontSize: 24,
                decoration: TextDecoration.none,
                fontFamily: 'NotoColorEmoji',
              ),
            ),
          ),
        );
      },
    );
  }


  int customSort(Emoji a, Emoji b) {
    // List of emojis you want to prioritize (e.g. thumbs up)
    const List<String> priorityEmojis = ['👍', '👎'];

    // Check if either emoji A or B is in the priority list
    bool aIsPriority = priorityEmojis.contains(a.char);
    bool bIsPriority = priorityEmojis.contains(b.char);

    if (aIsPriority && !bIsPriority) {
      return -1;
    } else if (!aIsPriority && bIsPriority) {
      return 1;
    } else {
      // If both are priority emojis or both are not, sort based on their Unicode value
      return a.char.compareTo(b.char);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      child: Material( // Add this line
        child: Column(
          children: [

            TabBar(
              controller: _tabController,
              isScrollable: true, // Add this line to make the TabBar scrollable
              tabs: _emojiGroups.map((group) {
                String label;

                switch (group) {
                  case EmojiGroup.smileysEmotion:
                    label = '🙂';
                    break;

                  case EmojiGroup.activities:
                    label = '🏀';
                    break;
                  case EmojiGroup.peopleBody:
                    label = '👨';
                    break;
                  case EmojiGroup.objects:
                    label = '💡';
                    break;

                  case EmojiGroup.travelPlaces:
                    label = '🚀';
                    break;
                  case EmojiGroup.animalsNature:
                    label = '🐶';
                    break;
                  case EmojiGroup.foodDrink:
                    label = '🍔';
                    break;
                  case EmojiGroup.symbols:
                    label = '💕';
                    break;
                  case EmojiGroup.flags:
                    label = '🇺🇸';
                    break;
                  default:
                    label = '';
                }


                return Tab(
                  child: Container(
                    width: 40, // Set a fixed width for each tab
                    child: Center(child: Text(label)),
                  ),
                );
              }).toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _emojiGroups.map((group) => _buildEmojiGrid(group)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

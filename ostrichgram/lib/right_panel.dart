import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

// Wrapper for the right panel.  Doesn't do much , but does include some scroll behavior functionality

class RightPanel extends StatefulWidget {
  final ValueNotifier<List<Widget>> cachedItemsNotifier;
  final ValueNotifier<bool> shouldRequestFocus;

  RightPanel({required this.cachedItemsNotifier, required this.shouldRequestFocus});

  @override
  _RightPanelState createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  Ticker? _scrollTicker;
  double _scrollSpeed = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _scrollTicker?.dispose();
    super.dispose();
  }

  void _startScrolling(double speed) {
    _scrollSpeed = speed;
    _scrollTicker ??= createTicker((_) {
      _scrollController.jumpTo(_scrollController.offset + _scrollSpeed);
    })..start();
  }

  void _stopScrolling() {
    _scrollTicker?.stop();
    _scrollTicker = null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.cachedItemsNotifier,
      builder: (BuildContext context, List<Widget> cachedItems, Widget? child) {
        WidgetsBinding.instance!.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            WidgetsBinding.instance!.addPostFrameCallback((_) async {
              if (_scrollController.hasClients) {
                await Future.delayed(Duration(milliseconds: 100));
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 1),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
          if (!_focusNode.hasFocus && widget.shouldRequestFocus.value) {
            _focusNode.requestFocus();
          }
        });

        return Theme(
          data: ThemeData(
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.all<Color>(Colors.blue.withOpacity(0.3)),
            ),
          ),
          child: RawKeyboardListener(
            focusNode: _focusNode,
            onKey: (RawKeyEvent event) {
              if (event is RawKeyDownEvent) {
                double scrollAmount = MediaQuery.of(context).size.height * 0.1;
                if (event.logicalKey == LogicalKeyboardKey.pageUp) {
                  _startScrolling(-scrollAmount);
                } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
                  _startScrolling(scrollAmount);
                }
              } else if (event is RawKeyUpEvent) {
                if (event.logicalKey == LogicalKeyboardKey.pageUp ||
                    event.logicalKey == LogicalKeyboardKey.pageDown) {
                  _stopScrolling();
                }
              }
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _scrollController,
                children: cachedItems,
              ),
            ),
          ),
        );
      },
    );
  }
}

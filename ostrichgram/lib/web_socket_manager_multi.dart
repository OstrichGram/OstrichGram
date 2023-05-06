import 'dart:async';
import 'dart:convert';
import 'dart:io';

/*

This class is a singleton instance so we can call it from anywhere in the app and get the same instance.  The
primary function is the openPersistentWebSocket function which is designed to keep open a connection
with a websocket, pass any messages needed, and put all responses into a buffer which we collect
periodically from the main.dart.  There is an inactivity timeout , an initial connection timeout,
and some size limits implemented.

This class expands on the original implementation by supporting multiple websockets. Now
we have an array of everything: websockets, buffers, statuses, inactivityTimers, and requests.
We now store the original request with each websocket so we can easily refer back to it -- for example,
to get the e tag filter so we can store the cache watermark.


 */
class WebSocketManagerMulti {
  Map<int, WebSocket?> _webSockets = {};
  Map<int, List<String>> _buffers = {};
  Map<int, int> _statuses = {};
  Map<int, String> _uris = {};
  Map<int, Timer?> _inactivityTimers = {};
  Map<int, bool> _shouldCloseMap = {};
  Map<int, int> _bufferSizes = {};
  Map<int, String> _requests = {};
  Duration _inactivityTimeout = Duration(
      seconds: 900); // Set your desired timeout duration


  String getCurrentRequest(int socketId) {
    if (!_statuses.containsKey(socketId)) {
      throw ArgumentError(
          'No WebSocket connection found with the provided socketId');
    }
    if (_requests[socketId]== null) {
      return "";
    }
    else return _requests[socketId]!;
  }


  int getStatus(int socketId) {
    if (!_statuses.containsKey(socketId)) {
      throw ArgumentError(
          'No WebSocket connection found with the provided socketId');
    }
    return _statuses[socketId]!;
  }

  String getUri(int socketId) {
    if (!_uris.containsKey(socketId) || _uris[socketId] == null) {
      return '';
    }
    return _uris[socketId]!;
  }


  // Singleton pattern
  static final WebSocketManagerMulti _instance = WebSocketManagerMulti
      ._internal();

  factory WebSocketManagerMulti() {
    return _instance;
  }

  WebSocketManagerMulti._internal() {
    _buffers[0] = [];
    _statuses[0] = WebSocket.closed;
    _uris[0] = '';
    _inactivityTimers[0] = null;
    _shouldCloseMap[0] = false;
    _bufferSizes[0] = 0;
  }


  Future<void> send(int socketId, String message, {bool storeRequest=false}) async {
    if (_webSockets[socketId] != null &&
        _webSockets[socketId]!.readyState == WebSocket.open) {
      _webSockets[socketId]!.add(message);
      if (storeRequest) {
         _requests[socketId]  = message;
      }

    } else {
      print(
          'The WebSocketManager is trying to send a message, but the connection is not open.');
      throw 'The WebSocketManager is trying to send a message, but the connection is not open.';
    }
  }

  void _resetInactivityTimer(int socketId) {
    _inactivityTimers[socketId]?.cancel();
    _inactivityTimers[socketId] = Timer(_inactivityTimeout, () {
      print("Inactivity timeout reached. Closing WebSocket $socketId.");
      closeWebSocketConnection(socketId);
    });
  }

  Future<int> openPersistentWebSocket(int socketId, String url) async {
    if (_statuses.containsKey(socketId) && _statuses[socketId] != 0) {
      return 1;
    }


    _buffers[socketId] = [];
    _bufferSizes[socketId] = 0;

    _statuses[socketId] = 1;
    _shouldCloseMap[socketId] = false;

    try {
      _webSockets[socketId] = await _connectWithTimeout(socketId,url, Duration(seconds: 10));
      _webSockets[socketId]!.listen(
            (data) {
          if (_shouldCloseMap[socketId]!) return;

          // Check if the received data is a ping frame (opcode 0x9)
          if (data is List<int> && data.length == 2 && data[0] == 0x89 &&
              data[1] == 0x0) {
            // Respond with a pong frame (opcode 0xA)
            _webSockets[socketId]!.add([0x8A, 0x0]);
            return;
          }

          // Reset the inactivity timer every time data is received
          _resetInactivityTimer(socketId);

          if (data.length > 100 * 1024) {
            print("Warning: Event exceeds the 100 KB limit, size: ${data
                .length}");
            return;
          }

          if (_bufferSizes[socketId]! + data.length > 100 * 1024 * 1024) {
            return;
          }

          // data is the key variable here that's added to the buffer.
          _bufferSizes[socketId] =
              _bufferSizes[socketId]! + (data.length as int);

          _buffers[socketId]!.add(data);

          List<dynamic> decodedData = jsonDecode(data);
        },
        onDone: () {
          _statuses[socketId] = 0;
          _inactivityTimers[socketId]
              ?.cancel(); // Cancel the timer when the connection is closed
        },
        onError: (error) {
          print('Error: $error');
          _statuses[socketId] = 0;
          _inactivityTimers[socketId]
              ?.cancel(); // Cancel the timer when an error occurs
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _statuses[socketId] = 0;
    }
    // Set a _url class variable so we can double check later we are on the right relay to avoid problems in the ui.
    _uris[socketId] = url;
    return 0;
  }


  Future<WebSocket> _connectWithTimeout(int socketId, String url,
      Duration timeout) async {
    final completer = Completer<WebSocket>();

    Future.delayed(timeout).then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('WebSocket connection timed out', timeout));
      }
    });

    WebSocket.connect(url).then((socket) {
      if (!completer.isCompleted) {
        _webSockets[socketId] = socket;
        completer.complete(socket);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }


  void closeWebSocketConnection(int socketId) {
    _webSockets[socketId]?.close();
    _statuses[socketId] = 0;
    _uris[socketId] = "";
    _inactivityTimers[socketId]?.cancel();
  }

  bool isWebSocketOpen(int socketId) {
    return _webSockets[socketId] != null &&
        _webSockets[socketId]?.readyState == WebSocket.open;
  }

  List<String> collectWebSocketBuffer(int socketId) {

    if (!_buffers.containsKey(socketId) || _buffers[socketId] == null) {
      print('No buffer found or buffer is null for the provided socketId: $socketId');
      return [];
    }

    List<String> fetchedData = List<String>.from(_buffers[socketId]!);
    _buffers[socketId]?.clear();
    return fetchedData;
  }


  List<String> fetchData(int socketId) {
    if (_statuses[socketId] != 0) {
      print('WebSocketManager is not ready to fetch data.');
      return [];
    }

    List<String> fetchedData = List<String>.from(_buffers[socketId]!);
    _buffers[socketId]?.clear();
    return fetchedData;
  }


}
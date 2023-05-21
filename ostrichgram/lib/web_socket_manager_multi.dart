import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';


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
    _statuses[0] = 0;
    _uris[0] = '';
    _inactivityTimers[0] = null;
    _shouldCloseMap[0] = false;
    _bufferSizes[0] = 0;
  }


  Future<List<int>> getActiveSockets() async {
    List<int> activeSockets = [];
    _statuses.forEach((socketId, status) {
      if (status == 1) {
        activeSockets.add(socketId);
      }
    });
    return activeSockets;
  }


  Future<void> createFatGroup(String kind40_msg, String kind41_msg, String relays) async {
    // First, terminate all connections.
    closeAllWebSocketConnections();

    // Put items into list
    List<String> relay_list = relays.split(",");
    int number_relays = relay_list.length;

    // Trim the relays from whitespace.
    for (int i = 0; i < number_relays; i++) {
      relay_list[i]=relay_list[i].trim();
    }

    // Create a list to store socket IDs
    List<int> socketIds = [];

    // Initialize a random number generator
    Random random = Random();

    // Prepare a list of Futures for kind40 messages
    List<Future<void>> kind40Futures = [];

    // Prepare a list of Futures for kind41 messages
    List<Future<void>> kind41Futures = [];

    for (int i = 0; i < number_relays; i++) {
      int socketId;

      // Generate a unique socket ID and check if it exists
      do {
        socketId = random.nextInt(10000) + 1;
      } while (socketIds.contains(socketId));

      // Add the unique socket ID to the list
      socketIds.add(socketId);

      // Prepare to open a new WebSocket connection with the relay and send kind40 message
      kind40Futures.add(singleServeSocketMessage(socketId, relay_list[i], kind40_msg));

      // Prepare to open a new WebSocket connection with the relay and send kind41 message
      kind41Futures.add(singleServeSocketMessage(socketId, relay_list[i], kind41_msg));
    }

    try {
      // Send all kind40 messages concurrently and wait for them to complete
      await Future.wait(kind40Futures, eagerError: false);

      // Wait for 50ms
      await Future.delayed(Duration(milliseconds: 50));

      // Send all kind41 messages concurrently and wait for them to complete
      await Future.wait(kind41Futures, eagerError: false);
    } catch (e) {
      // Handle any exceptions that occurred while sending the messages. Note this will only catch the first exception (e) from any of the websocket calls.
      print(e);
    }

    return;
  }



  Future<void> send(int socketId, String message, {bool storeRequest=false}) async {

// Check if the WebSocket associated with the provided socketId exists.
    if (_webSockets[socketId] == null) {
      throw 'WebSocket for socketId $socketId does not exist.';
    }

    // Check the readyState of the WebSocket.
    if (_webSockets[socketId]!.readyState != WebSocket.open) {
      throw 'WebSocket for socketId $socketId is not open.';
    }
    if (_webSockets[socketId] != null &&
        _webSockets[socketId]!.readyState == WebSocket.open) {
      _webSockets[socketId]!.add(message);
      if (storeRequest) {
         _requests[socketId]  = message;
      }

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

  Future<void> singleServeSocketMessage(int socketId, String url, String message) async {

    // open a socket, send a message, close it.  used for fatgroup creation where we want to send a bunch of 40 and 41 to various re
    try {
      // Open WebSocket connection with a timeout
      WebSocket webSocket = await WebSocket.connect(url).timeout(Duration(seconds: 10));

      // Save the webSocket in the _webSockets map using the socketId
      _webSockets[socketId] = webSocket;

      // Once the connection is opened, listen for incoming data
      _webSockets[socketId]!.listen(
            (data) {
          // You can handle any incoming data here if needed
        },
        onDone: () {
          print('WebSocket connection closed for socketId: $socketId');
        },
        onError: (error) {
          print('Error for socketId $socketId: $error');
        },
      );

      // Send the message
      _webSockets[socketId]!.add(message);

      // Close the WebSocket connection
      await _webSockets[socketId]!.close();

      // Remove the WebSocket from the _webSockets map
      _webSockets.remove(socketId);
    } catch (e) {
      print('Error connecting to WebSocket for socketId $socketId: $e');
    }
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

  int getCleanSocketId() {
    const int maxSocketId = 10000;
    const int minSocketId = 1;
    const int closedStatus = 0;

    // Initialize a random number generator
    Random random = Random();

    int socketId;

    // Generate a unique socket ID and check if it exists and is closed
    do {
      socketId = random.nextInt(maxSocketId) + minSocketId;
    } while (_statuses.containsKey(socketId) && _statuses[socketId] != closedStatus);

    // Initialize the socket properties
    _webSockets[socketId] = null;
    _buffers[socketId] = [];
    _statuses[socketId] = 0;
    _uris[socketId] = '';
    _inactivityTimers[socketId] = null;
    _shouldCloseMap[socketId] = false;
    _bufferSizes[socketId] = 0;
    _requests[socketId] = '';

    return socketId;
  }


  void closeAllWebSocketConnections() {
    for (int socketId in _webSockets.keys) {
      closeWebSocketConnection(socketId);
    }
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


  List<String> collectWebSocketBufferAll() {
// Collects but also puts the "relay" and socket id in.

    List<String> fetchedData = [];
    List<String> buffer_items = [];

    _statuses.forEach((socketId, status) {
      if (status == 1 && _buffers.containsKey(socketId) && _buffers[socketId] != null) {
        buffer_items = _buffers[socketId]!;

        for (var item in buffer_items) {
          // Parse string into json
          var itemJson = jsonDecode(item);

          // Check if the json item is a list
          if (itemJson is List<dynamic>) {
            // Add "relay" field to the main dictionary of the event
            if (itemJson.length >= 3 && itemJson[2] is Map<String, dynamic>) {
              itemJson[2]['relay'] = _uris[socketId];
              itemJson[2]['socket'] = socketId;
            }
          }

          // Encode the json back into a string and add it to fetchedData
          fetchedData.add(jsonEncode(itemJson));
        }

        _buffers[socketId]!.clear();
      }
    });

    return fetchedData;
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
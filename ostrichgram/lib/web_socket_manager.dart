import 'dart:async';
import 'dart:convert';
import 'dart:io';

/*

This class is a singleton instance so we can call it from anywhere in the app and get the same instance.  The
primary function is the openPersistentWebSocket function which is designed to keep open a connection
with a websocket, pass any messages needed, and put all responses into a buffer which we collect
periodically from the main.dart.  There is an inactivity timeout , an initial connection timeout,
and some size limits implemented.

The app development began with neo primary connection implemented in this class to use  one relay open at a time, with some secondary
connections implemented in the future for the content manager.  But subsequently, we have web_socket_manager_multi.dart.

 */

class WebSocketManager {
  int _bufferSize = 0;
  int _status = 0;
  WebSocket? _webSocket;
  List<String> _buffer = [];
  bool _shouldClose = false;
  String _uri ="";
  int get status => _status;
  String get uri => _uri;
  Duration _inactivityTimeout = Duration(seconds: 900); // Set your desired timeout duration
  Timer? _inactivityTimer;

  // Singleton pattern
  static final WebSocketManager _instance = WebSocketManager._internal();

  factory WebSocketManager() {
    return _instance;
  }

  WebSocketManager._internal();

  Future<void> send(String message) async {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(message);
    } else {
      print('The WebSocketManager is trying to send a message, but the connection is not open.');
      throw 'The WebSocketManager is trying to send a message, but the connection is not open.';
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Doesn't actually close the socket, just passes the function to close it later , which is what we want.
    _inactivityTimer = Timer(_inactivityTimeout, () {
      print("Inactivity timeout reached. Closing WebSocket.");
      closeWebSocketConnection();
    });
  }



  Future<int> openPersistentWebSocket(String url) async {
    if (_status != 0) {
      return 1;
    }

    _buffer.clear();
    _bufferSize = 0;

    _status = 1;
    _shouldClose = false;

    try {
      _webSocket = await _connectWithTimeout(url, Duration(seconds: 10));
      _webSocket!.listen(
            (data) {
          if (_shouldClose) return;

          // Check if the received data is a ping frame (opcode 0x9)
          if (data is List<int> && data.length == 2 && data[0] == 0x89 && data[1] == 0x0) {
            // Respond with a pong frame (opcode 0xA)
            _webSocket!.add([0x8A, 0x0]);
            return;
          }

          // Reset the inactivity timer every time data is received
          _resetInactivityTimer();

          if (data.length > 100 * 1024) {
            print("Warning: Event exceeds the 100 KB limit, size: ${data.length}");
            return;
          }

          if (_bufferSize + data.length > 100 * 1024 * 1024) {
            return;
          }

          // data is the key variable here that's added to the buffer.
          _bufferSize += data.length as int;
          _buffer.add(data);

          List<dynamic> decodedData = jsonDecode(data);
        },
        onDone: () {
          _status = 0;
          _inactivityTimer?.cancel(); // Cancel the timer when the connection is closed
        },
        onError: (error) {
          print('Error: $error');
          _status = 0;
          _inactivityTimer?.cancel(); // Cancel the timer when an error occurs
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _status = 0;
    }
    // Set a _url class variable so we can double check later we are on the right relay to avoid problems in the ui.
    _uri = url;
    return 0;
  }


  Future<WebSocket> _connectWithTimeout(String url, Duration timeout) async {
    final completer = Completer<WebSocket>();

    Future.delayed(timeout).then((_) {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('WebSocket connection timed out', timeout));
      }
    });

     WebSocket.connect(url).then((socket) {
      if (!completer.isCompleted) {
        completer.complete(socket);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }


  Future<int> openWebSocketConnection(String url) async {
    if (_status != 0) {
      return 1;
    }

    _status = 1;
    _shouldClose = false;
    try {
      _webSocket = await WebSocket.connect(url);
      _webSocket!.listen(
            (data) {
          if (_shouldClose) return;

          _buffer.add(data);
          List<dynamic> decodedData = jsonDecode(data);
          if (decodedData is List && decodedData.isNotEmpty && decodedData[0] == "EOSE") {
            _shouldClose = true;
            _webSocket!.close();
          }
        },
        onDone: () {
          _status = 0;
        },
        onError: (error) {
          print('Error: $error');
          _status = 0;
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _status = 0;
    }
    return 0;
  }

  void closeWebSocketConnection() {
    _webSocket?.close();
    _status = 0;
    _uri = "";
    _inactivityTimer?.cancel();
  }

  bool isWebSocketOpen() {
    return _webSocket != null && _webSocket?.readyState == WebSocket.open;
  }

  List<String> collectWebSocketBuffer() {
    List<String> fetchedData = List<String>.from(_buffer);
    _buffer.clear();
    return fetchedData;
  }



  List<String> fetchData() {
    if (_status != 0) {
      print('WebSocketManager is not ready to fetch data.');
      return [];
    }

    List<String> fetchedData = List<String>.from(_buffer);
    _buffer.clear();
    return fetchedData;
  }
}

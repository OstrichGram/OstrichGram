import 'dart:async';
import 'package:synchronized/synchronized.dart';
/*
Not implemented yet, but the idea of this class is run this process and check periodically (say every 5 seconds)
if we need to fetch information in the background.  That way the client can keep up with multiple conversations
in the background even if not in the current window.

 */

class ContentManager {

  final _dbLock = Lock();

  Timer? _timer;

  void start() {

    // Not implemented yet.

    // Uncomment to start the timer
    //_timer = Timer.periodic(Duration(seconds: 5), (Timer t) => _performTasks());
  }

  void stop() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  Future<void> _performDbOperation() async {
    return _dbLock.synchronized(() async {
      // Perform your database operation here
    });
  }


void _performTasks() {
    // Not implemented yet
  }
}


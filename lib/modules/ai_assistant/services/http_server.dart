import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class HttpServer {
  io.HttpServer? _server;
  bool _ready = false;
  final Router _router = Router();

  bool get isReady => _ready;
  Router get router => _router;

  Future<void> start({int port = 8080}) async {
    _server = await shelf_io.serve(
      Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_router),
      io.InternetAddress.loopbackIPv4,
      port,
    );
    _ready = true;
    if (kDebugMode) {
      print('[HttpServer] Running on http://127.0.0.1:$port');
    }
  }

  Future<void> stop() async {
    _ready = false;
    await _server?.close();
    _server = null;
  }
}

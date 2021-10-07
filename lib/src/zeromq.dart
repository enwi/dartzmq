library dartzmq;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

String _platformPath(String name, {String? path}) {
  path = path ?? "";
  if (Platform.isLinux || Platform.isAndroid) {
    return path + "lib" + name + ".so";
  }
  if (Platform.isMacOS) {
    return path + "lib" + name + ".dylib";
  }
  if (Platform.isWindows) {
    return path + name + ".dll";
  }
  throw Exception("Platform not implemented");
}

DynamicLibrary _dlOpenPlatformSpecific(String name, {String? path}) {
  String fullPath = _platformPath(name, path: path);
  return DynamicLibrary.open(fullPath);
}

/// High-level wrapper around the ØMQ C++ api.
class ZeroMQ {
  late final ZeroMQBindings _bindings;
  late final ZMQContext _context;
  late final ZMQPoller _poller;

  bool _isActive = true;
  bool _pollingMicrotaskScheduled = false;

  final Map<ZMQSocket, ZmqSocket> _createdSockets = {};
  final List<ZmqSocket> _listening = [];
  Completer? _stopCompleter;

  ZeroMQ() {
    _initBindings();
    _context = _bindings.zmq_ctx_new();
    _poller = _bindings.zmq_poller_new();
    _startPolling();
  }

  void _initBindings() {
    // try {
    _bindings = ZeroMQBindings(_dlOpenPlatformSpecific('libzmq-v142-mt-4_3_5'));
    // } catch (err) {
    //   log('Error loading bindings: ' + err.toString());
    // }
  }

  Future stop() {
    _isActive = false;
    _stopCompleter = Completer();
    return _stopCompleter!.future;
  }

  ZMQMessage _allocateMessage() {
    return malloc.allocate<Uint8>(64).cast();
  }

  void _startPolling() {
    if (!_pollingMicrotaskScheduled && _listening.isNotEmpty) {
      _pollingMicrotaskScheduled = true;
      scheduleMicrotask(_poll);
    }
  }

  void _poll() {
    final listeners = _listening.length;
    final events = malloc.allocate<ZMQPollerEvent>(listeners);
    final readEvents =
        _bindings.zmq_poller_wait_all(_poller, events, listeners, 0);

    final msg = _allocateMessage();
    for (var i = 0; i < readEvents; i++) {
      final event = events[i];
      final socket = _createdSockets[event.socket]!;

      // Receive multiple message parts
      while (true) {
        var rc = _bindings.zmq_msg_init(msg);
        _checkSuccess(rc);

        rc = _bindings.zmq_msg_recv(msg, socket._handle, 0);
        _checkSuccess(rc, positiveIsSuccess: true);

        final size = _bindings.zmq_msg_size(msg);
        final data = _bindings.zmq_msg_data(msg).cast<Uint8>();

        final copyOfData = Uint8List.fromList(data.asTypedList(size));
        final hasNext = _bindings.zmq_msg_more(msg) != 0;

        socket._controller.add(Message(copyOfData, hasMore: hasNext));
        if (!hasNext) break;
      }
      _bindings.zmq_msg_close(msg);
    }

    malloc.free(msg);
    malloc.free(events);

    // After the polling iteration, re-schedule another one if necessary.
    if (_isActive) {
      if (_listening.isNotEmpty) {
        // NOT using scheduleMicrotask because it blocks up the queue
        Timer.run(_poll);
        return;
      }
    } else {
      _shutdownInternal();
      _stopCompleter?.complete(null);
    }
    // no polling necessary, reset flag so that the next call to _startPolling
    // will bring the mechanism back up.
    _pollingMicrotaskScheduled = false;
  }

  ZmqSocket createSocket(SocketMode mode) {
    final socket = _bindings.zmq_socket(_context, mode.index);
    final apiSocket = ZmqSocket(socket, this);
    _createdSockets[socket] = apiSocket;
    return apiSocket;
  }

  void _listen(ZmqSocket socket) {
    _bindings.zmq_poller_add(_poller, socket._handle, nullptr, ZMQ_POLLIN);
    _listening.add(socket);
    _startPolling();
  }

  void _stopListening(ZmqSocket socket) {
    _bindings.zmq_poller_remove(_poller, socket._handle);
    _listening.remove(socket);
  }

  void _handleSocketClosed(ZmqSocket socket) {
    if (_isActive) {
      _createdSockets.remove(socket._handle);
    }
    if (_listening.contains(socket)) {
      _stopListening(socket);
    }
  }

  void _shutdownInternal() {
    for (final socket in _createdSockets.values) {
      socket.close();
    }
    _createdSockets.clear();
    _listening.clear();

    _bindings.zmq_ctx_term(_context);

    // final pollerPtrPtr = malloc.allocate<ZMQPoller>(0);
    // pollerPtrPtr.value = _poller;
    _bindings.zmq_poller_destroy(_poller);
    malloc.free(_poller);
  }

  void _checkSuccess(int statusCode, {bool positiveIsSuccess = false}) {
    final isFailure = positiveIsSuccess ? statusCode < 0 : statusCode != 0;

    if (isFailure) {
      final errorCode = _bindings.zmq_errno();
      throw ZeroMQException(errorCode);
    }
  }
}

enum SocketMode {
  pair,
  pub,
  sub,
  req,
  rep,
  dealer,
  router,
  pull,
  push,
  xPub,
  xSub,
  stream
}

class Message {
  final Uint8List payload;
  final bool hasMore;

  Message(this.payload, {this.hasMore = false});
}

class ZmqSocket {
  final ZMQSocket _handle;
  final ZeroMQ _zmq;

  bool _closed = false;

  late final StreamController<Message> _controller;
  Stream<Message> get messages => _controller.stream;
  Stream<Uint8List> get payloads => messages.map((m) => m.payload);

  ZmqSocket(this._handle, this._zmq) {
    _controller = StreamController(onListen: () {
      _zmq._listen(this);
    }, onCancel: () {
      _zmq._stopListening(this);
    });
  }

  /// Sends the [data] payload over this socket.
  ///
  /// The [more] parameter (defaults to false) signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  void send(List<int> data, {bool more = false}) {
    _checkNotClosed();
    final ptr = malloc.allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    final sendParams = more ? ZMQ_SNDMORE : 0;
    final result =
        _zmq._bindings.zmq_send(_handle, ptr.cast(), data.length, sendParams);
    _zmq._checkSuccess(result, positiveIsSuccess: true);
    malloc.free(ptr);
  }

  void bind(String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _zmq._bindings.zmq_bind(_handle, endpointPointer);
    _zmq._checkSuccess(result);
    malloc.free(endpointPointer);
  }

  void connect(String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _zmq._bindings.zmq_connect(_handle, endpointPointer);
    _zmq._checkSuccess(result);
    malloc.free(endpointPointer);
  }

  void close() {
    if (!_closed) {
      _zmq._handleSocketClosed(this);
      _zmq._bindings.zmq_close(_handle);
      _controller.close();
      _closed = true;
    }
  }

  void setOption(int option, String value) {
    final ptr = value.toNativeUtf8();
    _zmq._bindings
        .zmq_setsockopt(_handle, option, ptr.cast<Uint8>(), ptr.length);
    malloc.free(ptr);
  }

  void setCurvePublicKey(String key) {
    setOption(ZMQ_CURVE_PUBLICKEY, key);
  }

  void setCurveSecretKey(String key) {
    setOption(ZMQ_CURVE_SECRETKEY, key);
  }

  void setCurveServerKey(String key) {
    setOption(ZMQ_CURVE_SERVERKEY, key);
  }

  void _checkNotClosed() {
    if (_closed) {
      throw StateError("This operation can't be performed on a cosed socket!");
    }
  }
}

class ZeroMQException implements Exception {
  final int errorCode;

  ZeroMQException(this.errorCode);

  @override
  String toString() {
    final msg = _errorMessages[errorCode];
    if (msg == null) {
      return 'ZeroMQException($errorCode)';
    } else {
      return 'ZeroMQException: $msg';
    }
  }

  static const Map<int, String> _errorMessages = {
    EPROTONOSUPPORT: 'The requested transport protocol is not supported',
    EADDRINUSE: 'The requested address is already in use',
  };
}

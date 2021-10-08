library dartzmq;

import 'dart:async';
import 'dart:collection';
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
      final zMessage = ZMessage();
      while (true) {
        var rc = _bindings.zmq_msg_init(msg);
        _checkSuccess(rc);

        rc = _bindings.zmq_msg_recv(msg, socket._handle, 0);
        _checkSuccess(rc, positiveIsSuccess: true);

        final size = _bindings.zmq_msg_size(msg);
        final data = _bindings.zmq_msg_data(msg).cast<Uint8>();

        final copyOfData = Uint8List.fromList(data.asTypedList(size));
        final hasNext = _bindings.zmq_msg_more(msg) != 0;

        zMessage.add(ZFrame(copyOfData, hasMore: hasNext));
        if (!hasNext) break;
      }
      // TODO need to check if zMessage.isEmpty ?
      socket._controller.add(zMessage);
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

/// ZFrame
///
/// A 'frame' corresponds to one underlying zmq_msg_t in the libzmq code.
/// When you read a frame from a socket, the [hasMore] member indicates
/// if the frame is part of an unfinished multipart message.
class ZFrame {
  /// The payload that was received or is to be sent
  final Uint8List payload;

  /// Is this frame part of an unfinished multipart message?
  final bool hasMore;

  ZFrame(this.payload, {this.hasMore = false});
}

/// ZMessage
///
/// This class provides a list-like container interface,
/// with methods to work with the overall container. ZMessage messages are
/// composed of zero or more ZFrame objects.
class ZMessage implements Queue<ZFrame> {
  final DoubleLinkedQueue<ZFrame> _frames = DoubleLinkedQueue();

  @override
  Iterator<ZFrame> get iterator => _frames.iterator;

  @override
  void add(ZFrame value) => _frames.add;

  @override
  void addAll(Iterable<ZFrame> iterable) => _frames.addAll(iterable);

  @override
  void addFirst(ZFrame value) => _frames.addFirst(value);

  @override
  void addLast(ZFrame value) => _frames.addLast(value);

  @override
  void clear() => _frames.clear();

  @override
  bool remove(Object? value) => _frames.remove(value);

  @override
  ZFrame removeFirst() => _frames.removeFirst();

  @override
  ZFrame removeLast() => _frames.removeLast();

  @override
  void removeWhere(bool Function(ZFrame element) test) =>
      _frames.removeWhere(test);

  @override
  void retainWhere(bool Function(ZFrame element) test) =>
      _frames.retainWhere(test);

  @override
  bool any(bool Function(ZFrame element) test) => _frames.any(test);

  @override
  Queue<R> cast<R>() => _frames.cast<R>();

  @override
  bool contains(Object? element) => _frames.contains(element);

  @override
  ZFrame elementAt(int index) => _frames.elementAt(index);

  @override
  bool every(bool Function(ZFrame element) test) => _frames.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(ZFrame element) toElements) =>
      _frames.expand(toElements);

  @override
  ZFrame get first => _frames.first;

  @override
  ZFrame firstWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue,
          T Function(T previousValue, ZFrame element) combine) =>
      _frames.fold(initialValue, combine);

  @override
  Iterable<ZFrame> followedBy(Iterable<ZFrame> other) =>
      _frames.followedBy(other);

  @override
  void forEach(void Function(ZFrame element) action) => _frames.forEach(action);

  @override
  bool get isEmpty => _frames.isEmpty;

  @override
  bool get isNotEmpty => _frames.isNotEmpty;

  @override
  String join([String separator = ""]) => _frames.join(separator);

  @override
  ZFrame get last => _frames.last;

  @override
  ZFrame lastWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.lastWhere(test, orElse: orElse);

  @override
  int get length => _frames.length;

  @override
  Iterable<T> map<T>(T Function(ZFrame e) toElement) => _frames.map(toElement);

  @override
  ZFrame reduce(ZFrame Function(ZFrame value, ZFrame element) combine) =>
      _frames.reduce(combine);

  @override
  ZFrame get single => _frames.single;

  @override
  ZFrame singleWhere(bool Function(ZFrame element) test,
          {ZFrame Function()? orElse}) =>
      _frames.singleWhere(test, orElse: orElse);

  @override
  Iterable<ZFrame> skip(int count) => _frames.skip(count);

  @override
  Iterable<ZFrame> skipWhile(bool Function(ZFrame value) test) =>
      _frames.skipWhile(test);

  @override
  Iterable<ZFrame> take(int count) => _frames.take(count);

  @override
  Iterable<ZFrame> takeWhile(bool Function(ZFrame value) test) =>
      _frames.takeWhile(test);

  @override
  List<ZFrame> toList({bool growable = true}) =>
      _frames.toList(growable: growable);

  @override
  Set<ZFrame> toSet() => _frames.toSet();

  @override
  Iterable<ZFrame> where(bool Function(ZFrame element) test) =>
      _frames.where(test);

  @override
  Iterable<T> whereType<T>() => _frames.whereType<T>();
}

class ZmqSocket {
  final ZMQSocket _handle;
  final ZeroMQ _zmq;

  bool _closed = false;

  late final StreamController<ZMessage> _controller;
  Stream<ZMessage> get messages => _controller.stream;
  Stream<Uint8List> get payloads =>
      messages.expand((element) => element._frames.map((e) => e.payload));

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

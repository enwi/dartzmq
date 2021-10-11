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
class ZContext {
  late final ZMQBindings _bindings;
  late final ZMQContext _context;
  late final ZMQPoller _poller;

  bool _shutdown = false;
  Timer? _timer;

  final Map<ZMQSocket, ZSocket> _createdSockets = {};
  final List<ZSocket> _listening = [];
  Completer? _stopCompleter;

  ZContext() {
    _initBindings();
    _context = _bindings.zmq_ctx_new();
    _poller = _bindings.zmq_poller_new();
    _startPolling();
  }

  void _initBindings() {
    // try {
    _bindings = ZMQBindings(_dlOpenPlatformSpecific('libzmq-v142-mt-4_3_5'));
    // } catch (err) {
    //   log('Error loading bindings: ' + err.toString());
    // }
  }

  Future stop() {
    _shutdown = true;
    _stopCompleter = Completer();
    return _stopCompleter!.future;
  }

  ZMQMessage _allocateMessage() {
    return malloc.allocate<Uint8>(64).cast();
  }

  void _startPolling() {
    if (_timer == null && _listening.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _poll());
    }
  }

  void _poll() {
    final socketCount = _listening.length;

    final pollerEvents =
        malloc.allocate<ZMQPollerEvent>(sizeOf<ZMQPollerEvent>() * socketCount);
    final availableEventCount =
        _bindings.zmq_poller_wait_all(_poller, pollerEvents, socketCount, 0);

    if (availableEventCount > 0) {
      final msg = _allocateMessage();
      var rc = _bindings.zmq_msg_init(msg); // rc == 0
      _checkReturnCode(rc);

      for (var eventIdx = 0; eventIdx < availableEventCount; ++eventIdx) {
        final pollerEvent = pollerEvents[eventIdx];
        final socket = _createdSockets[pollerEvent.socket]!;

        // Receive multiple message parts
        ZMessage zMessage = ZMessage();
        bool hasMore = true;
        while ((rc =
                _bindings.zmq_msg_recv(msg, socket._socket, ZMQ_DONTWAIT)) >
            0) {
          // final size = _bindings.zmq_msg_size(msg);
          final data = _bindings.zmq_msg_data(msg).cast<Uint8>();

          final copyOfData = Uint8List.fromList(data.asTypedList(rc));
          hasMore = _bindings.zmq_msg_more(msg) != 0;

          zMessage.add(ZFrame(copyOfData, hasMore: hasMore));

          if (!hasMore) {
            socket._controller.add(zMessage);
            zMessage = ZMessage();
          }
        }

        _checkReturnCode(rc, ignore: [EAGAIN]);
      }

      rc = _bindings.zmq_msg_close(msg); // rc == 0
      _checkReturnCode(rc);

      malloc.free(msg);
    }

    malloc.free(pollerEvents);

    // After the polling iteration, re-schedule another one if necessary.
    if (_shutdown) {
      _shutdownInternal();
      _stopCompleter?.complete(null);
    } else if (socketCount > 0) {
      return;
    }

    // no polling necessary, reset flag so that the next call to _startPolling
    // will bring the mechanism back up.
    _timer?.cancel();
    _timer = null;
  }

  ZSocket createSocket(SocketMode mode) {
    final socket = _bindings.zmq_socket(_context, mode.index);
    final apiSocket = ZSocket(socket, this);
    _createdSockets[socket] = apiSocket;
    return apiSocket;
  }

  void _listen(ZSocket socket) {
    _bindings.zmq_poller_add(_poller, socket._socket, nullptr, ZMQ_POLLIN);
    _listening.add(socket);
    _startPolling();
  }

  void _stopListening(ZSocket socket) {
    _bindings.zmq_poller_remove(_poller, socket._socket);
    _listening.remove(socket);
  }

  void _handleSocketClosed(ZSocket socket) {
    if (!_shutdown) {
      _createdSockets.remove(socket._socket);
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

  void _checkReturnCode(int code, {List<int> ignore = const []}) {
    if (code < 0) {
      _checkErrorCode(ignore: ignore);
    }
  }

  void _checkErrorCode({List<int> ignore = const []}) {
    final errorCode = _bindings.zmq_errno();
    if (!ignore.contains(errorCode)) {
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
  void add(ZFrame value) => _frames.add(value);

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

class ZSocket {
  final ZMQSocket _socket;
  final ZContext _context;

  bool _closed = false;

  late final StreamController<ZMessage> _controller;
  Stream<ZMessage> get messages => _controller.stream;
  Stream<ZFrame> get frames => messages.expand((element) => element._frames);
  Stream<Uint8List> get payloads => frames.map((e) => e.payload);

  ZSocket(this._socket, this._context) {
    _controller = StreamController(onListen: () {
      _context._listen(this);
    }, onCancel: () {
      _context._stopListening(this);
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
    final result = _context._bindings
        .zmq_send(_socket, ptr.cast(), data.length, sendParams);
    _context._checkReturnCode(result);
    malloc.free(ptr);
  }

  void bind(String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _context._bindings.zmq_bind(_socket, endpointPointer);
    _context._checkReturnCode(result);
    malloc.free(endpointPointer);
  }

  void connect(String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _context._bindings.zmq_connect(_socket, endpointPointer);
    _context._checkReturnCode(result);
    malloc.free(endpointPointer);
  }

  void close() {
    if (!_closed) {
      _context._handleSocketClosed(this);
      _context._bindings.zmq_close(_socket);
      _controller.close();
      _closed = true;
    }
  }

  void setOption(int option, String value) {
    final ptr = value.toNativeUtf8();
    _context._bindings
        .zmq_setsockopt(_socket, option, ptr.cast<Uint8>(), ptr.length);
    malloc.free(ptr);
  }

  void setCurvePublicKey(final String key) {
    setOption(ZMQ_CURVE_PUBLICKEY, key);
  }

  void setCurveSecretKey(final String key) {
    setOption(ZMQ_CURVE_SECRETKEY, key);
  }

  void setCurveServerKey(final String key) {
    setOption(ZMQ_CURVE_SERVERKEY, key);
  }

  /// The [ZMQ_SUBSCRIBE] option shall establish a new message filter on a [ZMQ_SUB] socket.
  /// Newly created [ZMQ_SUB] sockets shall filter out all incoming messages, therefore you
  /// should call this option to establish an initial message filter.
  ///
  /// An empty [topic] of length zero shall subscribe to all incoming messages. A
  /// non-empty [topic] shall subscribe to all messages beginning with the specified
  /// prefix. Mutiple filters may be attached to a single [ZMQ_SUB] socket, in which case a
  /// message shall be accepted if it matches at least one filter.
  void subscribe(final String topic) {
    setOption(ZMQ_SUBSCRIBE, topic);
  }

  /// The [ZMQ_UNSUBSCRIBE] option shall remove an existing message filter on a [ZMQ_SUB]
  /// socket. The filter specified must match an existing filter previously established with
  /// the [ZMQ_SUBSCRIBE] option. If the socket has several instances of the same filter
  /// attached the [ZMQ_UNSUBSCRIBE] option shall remove only one instance, leaving the rest in
  /// place and functional.
  void unsubscribe(final String topic) {
    setOption(ZMQ_UNSUBSCRIBE, topic);
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
      return 'ZeroMQException($errorCode): $msg';
    }
  }

  static const Map<int, String> _errorMessages = {
    EPROTONOSUPPORT: 'The requested transport protocol is not supported',
    EADDRINUSE: 'The requested address is already in use',
  };
}

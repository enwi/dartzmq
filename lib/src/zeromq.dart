library dartzmq;

import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

String _platformPath(final String name, {String? path}) {
  path = path ?? '';
  if (Platform.isLinux || Platform.isAndroid) {
    return path + 'lib' + name + '.so';
  }
  if (Platform.isMacOS) {
    return path + 'lib' + name + '.dylib';
  }
  if (Platform.isWindows) {
    return path + name + '.dll';
  }
  throw Exception('Platform not implemented');
}

DynamicLibrary _dlOpenPlatformSpecific(final String name,
    {final String? path}) {
  String fullPath = _platformPath(name, path: path);
  return DynamicLibrary.open(fullPath);
}

/// High-level wrapper around the ØMQ C++ api.
class ZContext {
  /// Native bindings
  late final ZMQBindings _bindings;

  /// Native context
  late final ZMQContext _context;

  /// Native poller
  late final ZMQPoller _poller;

  /// Do we need to shutdown?
  bool _shutdown = false;

  /// Used for shutting down asynchronously
  Completer? _stopCompleter;

  /// Timer used for running [_poll] function
  Timer? _timer;

  /// Keeps track of all sockets created by [createSocket].
  /// Maps raw zeromq sockets [ZMQSocket] to our wrapper class [ZSocket].
  final Map<ZMQSocket, ZSocket> _createdSockets = {};

  /// Keeps track of all sockets that are currently being listened to
  final List<ZSocket> _listening = [];

  /// Create a new global ZContext
  ///
  /// Note only one context should exist throughout your application
  /// and it should be closed if the app is disposed
  ZContext() {
    _initBindings();
    _context = _bindings.zmq_ctx_new();
    _poller = _bindings.zmq_poller_new();
    _startPolling();
  }

  void _initBindings() {
    final loaded = _loadBinding('zmq') ||
        _loadBinding('libzmq') ||
        _loadBinding('libzmq-v142-mt-4_3_5');
    if (!loaded) {
      throw Exception('Could not load any zeromq library');
    }
  }

  bool _loadBinding(final String name) {
    try {
      _bindings = ZMQBindings(_dlOpenPlatformSpecific(name));
      return true;
    } catch (err) {
      log('Failed to load library $name:  ${err.toString()}', name: 'dartzmq');
    }
    return false;
  }

  /// Shutdown zeromq. Will stop [_poll] asynchronously.
  /// The returned [Future] will complete once [_poll] has been stopped
  Future stop() {
    _stopCompleter = Completer();
    _shutdown = true;
    return _stopCompleter!.future;
  }

  /// Allocates memory and casts it to a [ZMQMessage]
  ZMQMessage _allocateMessage() {
    return malloc.allocate<Uint8>(64).cast();
  }

  /// Starts the periodic polling task if it was not started already and
  /// if there are actually listeners on sockets
  void _startPolling() {
    if (_timer == null && _listening.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _poll());
    }
  }

  /// Polling task receiving and handling socket messages
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

    // Do we need to shutdown?
    if (_shutdown) {
      _shutdownInternal();
    } else if (socketCount > 0) {
      return;
    }

    // If we land here either there are no
    _timer?.cancel();
    _timer = null;
    _stopCompleter?.complete(null);
  }

  /// Check whether a specified [capability] is available in the library.
  /// This allows bindings and applications to probe a library directly,
  /// for transport and security options.
  ///
  /// Capabilities shall be lowercase strings. The following capabilities are defined:
  /// * `ipc` - the library supports the ipc:// protocol
  /// * `pgm` - the library supports the pgm:// protocol
  /// * `tipc` - the library supports the tipc:// protocol
  /// * `norm` - the library supports the norm:// protocol
  /// * `curve` - the library supports the CURVE security mechanism
  /// * `gssapi` - the library supports the GSSAPI security mechanism
  /// * `draft` - the library is built with the draft api
  ///
  /// You can also use one of the direct functions [hasIPC], [hasPGM],
  /// [hasTIPC], [hasNORM], [hasCURVE], [hasGSSAPI] and [hasDRAFT] instead.
  ///
  /// Returns true if supported, false if not
  bool hasCapability(final String capability) {
    final ptr = capability.toNativeUtf8();
    final result = _bindings.zmq_has(ptr);
    malloc.free(ptr);
    return result == 1;
  }

  /// Check if the library supports the ipc:// protocol
  ///
  /// Returns true if supported, false if not
  bool hasIPC() {
    return hasCapability('ipc');
  }

  /// Check if the library supports the pgm:// protocol
  ///
  /// Returns true if supported, false if not
  bool hasPGM() {
    return hasCapability('pgm');
  }

  /// Check if the library supports the tipc:// protocol
  ///
  /// Returns true if supported, false if not
  bool hasTIPC() {
    return hasCapability('tipc');
  }

  /// Check if the library supports the norm:// protocol
  ///
  /// Returns true if supported, false if not
  bool hasNORM() {
    return hasCapability('norm');
  }

  /// Check if the library supports the CURVE security mechanism
  ///
  /// Returns true if supported, false if not
  bool hasCURVE() {
    return hasCapability('curve');
  }

  /// Check if the library supports the GSSAPI security mechanism
  ///
  /// Returns true if supported, false if not
  bool hasGSSAPI() {
    return hasCapability('gssapi');
  }

  /// Check if the library is built with the draft api
  ///
  /// Returns true if supported, false if not
  bool hasDRAFT() {
    return hasCapability('draft');
  }

  /// Create a new socket of the given [mode]
  ZSocket createSocket(SocketType mode) {
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

    Pointer<ZMQPoller> pollerPointer = malloc.allocate<ZMQPoller>(0);
    pollerPointer.value = _poller;
    _bindings.zmq_poller_destroy(pollerPointer);
    malloc.free(pollerPointer);
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

/// All types of sockets
enum SocketType {
  /// [ZMQ_PAIR] = 0
  pair,

  /// [ZMQ_PUB] = 1
  pub,

  /// [ZMQ_SUB] = 2
  sub,

  /// [ZMQ_REQ] = 3
  req,

  /// [ZMQ_REP] = 4
  rep,

  /// [ZMQ_DEALER] = 5
  dealer,

  /// [ZMQ_ROUTER] = 6
  router,

  /// [ZMQ_PULL] = 7
  pull,

  /// [ZMQ_PUSH] = 8
  push,

  /// [ZMQ_XPUB] = 9
  xPub,

  /// [ZMQ_XSUB] = 10
  xSub,

  /// [ZMQ_STREAM] = 11
  stream
}

/// A ZFrame or 'frame' corresponds to one underlying zmq_msg_t in the libzmq code.
/// When you read a frame from a socket, the [hasMore] member indicates
/// if the frame is part of an unfinished multi-part message.
class ZFrame {
  /// The payload that was received or is to be sent
  final Uint8List payload;

  /// Is this frame part of an unfinished multi-part message?
  final bool hasMore;

  ZFrame(this.payload, {this.hasMore = false});

  @override
  String toString() => 'ZFrame[$payload]';
}

/// ZMessage provides a list-like container interface,
/// with methods to work with the overall container. ZMessage messages are
/// composed of zero or more ZFrame objects.
// typedef ZMessage = Queue<ZFrame>;
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
  String join([String separator = '']) => _frames.join(separator);

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

  @override
  String toString() =>
      IterableBase.iterableToFullString(this, 'ZMessage[', ']');
}

/// ZeroMQ sockets present an abstraction of an asynchronous message queue,
/// with the exact queuing semantics depending on the socket type in use.
/// Where conventional sockets transfer streams of bytes or discrete datagrams,
/// ZeroMQ sockets transfer discrete messages.
///
/// ZeroMQ sockets being asynchronous means that the timings of the physical
/// connection setup and tear down, reconnect and effective delivery are
/// transparent to the user and organized by ZeroMQ itself. Further, messages
/// may be queued in the event that a peer is unavailable to receive them.
class ZSocket {
  /// Native socket
  final ZMQSocket _socket;

  /// Global context
  final ZContext _context;

  /// Has this socket been closed?
  bool _closed = false;

  /// StreamController for providing received [ZMessage]s as a stream
  late final StreamController<ZMessage> _controller;

  /// Stream of received [ZMessage]s
  Stream<ZMessage> get messages => _controller.stream;

  /// Stream of received [ZFrame]s (expanded [messages] stream)
  Stream<ZFrame> get frames => messages.expand((element) => element._frames);

  /// Stream of received payloads (expanded [frames] strem)
  Stream<Uint8List> get payloads => frames.map((e) => e.payload);

  /// Construct a new [ZSocket] with a given underlying ZMQSocket [_socket] and the global ZContext [_context]
  ZSocket(this._socket, this._context) {
    _controller = StreamController(onListen: () {
      _context._listen(this);
    }, onCancel: () {
      _context._stopListening(this);
    });
  }

  /// Sends the given [data] payload over this socket.
  ///
  /// The [more] parameter (defaults to false) signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  void send(final List<int> data, {final bool more = false}) {
    _checkNotClosed();
    final ptr = malloc.allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    final sendParams = more ? ZMQ_SNDMORE : 0;
    final result = _context._bindings
        .zmq_send(_socket, ptr.cast(), data.length, sendParams);
    malloc.free(ptr);
    _context._checkReturnCode(result);
  }

  /// Sends the given [frame] over this socket
  ///
  /// This is a convenience function and is the same as calling
  /// [send(frame.payload, more: frame.hasMore)]
  void sendFrame(final ZFrame frame) {
    send(frame.payload, more: frame.hasMore);
  }

  /// Sends the given multi-part [message] over this socket
  ///
  /// This is a convenience function.
  /// Note that the individual [ZFrame.hasMore] are ignored
  void sendMessage(final ZMessage message) {
    final lastIndex = message.length - 1;
    for (int i = 0; i < message.length; ++i) {
      send(message.elementAt(i).payload, more: i < lastIndex ? true : false);
    }
  }

  /// Sends the given [string] payload over this socket.
  ///
  /// The [more] parameter (defaults to false) signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  void sendString(final String string, {final bool more = false}) {
    send(string.codeUnits, more: more);
  }

  /// Creates an endpoint for accepting connections and binds to it.
  ///
  /// The [address] argument is a string consisting of two parts as follows: 'transport://address'.
  /// The transport part specifies the underlying transport protocol to use.
  /// The meaning of the address part is specific to the underlying transport protocol selected.
  void bind(final String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _context._bindings.zmq_bind(_socket, endpointPointer);
    malloc.free(endpointPointer);
    _context._checkReturnCode(result);
  }

  /// Connects the socket to an endpoint and then accepts incoming connections on that endpoint.
  ///
  /// The [address] argument is a string consisting of two parts as follows: 'transport://address'.
  /// The transport part specifies the underlying transport protocol to use.
  /// The meaning of the address part is specific to the underlying transport protocol selected.
  void connect(final String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _context._bindings.zmq_connect(_socket, endpointPointer);
    malloc.free(endpointPointer);
    _context._checkReturnCode(result);
  }

  /// Closes the socket and releases underlying resources.
  /// Note after closing a socket it can't be reopened/reconncted again
  void close() {
    if (!_closed) {
      _context._handleSocketClosed(this);
      _context._bindings.zmq_close(_socket);
      _controller.close();
      _closed = true;
    }
  }

  /// Set a socket [option] to a specific [value]
  void setOption(final int option, final String value) {
    final ptr = value.toNativeUtf8();
    final result = _context._bindings
        .zmq_setsockopt(_socket, option, ptr.cast<Uint8>(), ptr.length);
    malloc.free(ptr);
    _context._checkReturnCode(result);
  }

  /// Sets the socket's long term secret key.
  /// You must set this on both CURVE client and server sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  void setCurveSecretKey(final String key) {
    setOption(ZMQ_CURVE_SECRETKEY, key);
  }

  /// Sets the socket's long term public key.
  /// You must set this on CURVE client sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  /// The public key must always be used with the matching secret key.
  void setCurvePublicKey(final String key) {
    setOption(ZMQ_CURVE_PUBLICKEY, key);
  }

  /// Sets the socket's long term server key.
  /// You must set this on CURVE client sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  /// This key must have been generated together with the server's secret key.
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
      throw StateError("This operation can't be performed on a closed socket!");
    }
  }
}

/// Custom Exception type for ZeroMQ specific exceptions
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

  /// Maps error codes to messages
  static const Map<int, String> _errorMessages = {
    // errno
    EINTR: 'EINTR: The operation was interrupted',
    EBADF: 'EBADF: Bad file descriptor',
    EAGAIN: 'EAGAIN', // denpendant on what function has been called before
    EACCES: 'EACCES: Permission denied',
    EFAULT: 'EFAULT', // denpendant on what function has been called before
    EINVAL: 'EINVAL', // denpendant on what function has been called before
    EMFILE: 'EMFILE', // denpendant on what function has been called before

    // 0MQ errors
    ENOTSUP: 'Not supported',
    EPROTONOSUPPORT: 'Protocol not supported',
    ENOBUFS: 'No buffer space available',
    ENETDOWN: 'Network is down',
    EADDRINUSE: 'Address in use',
    EADDRNOTAVAIL: 'Address not available',
    ECONNREFUSED: 'Connection refused',
    EINPROGRESS: 'Operation in progress',
    EFSM: 'Operation cannot be accomplished in current state',
    ENOCOMPATPROTO: 'The protocol is not compatible with the socket type',
    ETERM: 'Context was terminated',
    EMTHREAD: 'No thread available',
    EHOSTUNREACH: 'Host unreachable',
  };
}

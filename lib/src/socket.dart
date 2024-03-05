part of dartzmq;

/// All types of sockets
enum SocketType {
  /// [ZMQ_PAIR] = 0
  pair,

  /// [ZMQ_PUB] = 1
  pub,

  /// [ZMQ_SUB] = 2
  sub,

  /// [ZMQ_REQ] = 3
  /// Synchronous version of [ZMQ_DEALER]
  req,

  /// [ZMQ_REP] = 4
  /// Synchronous version of [ZMQ_ROUTER]
  rep,

  /// [ZMQ_DEALER] = 5
  /// Asynchronous version of [ZMQ_REQ]
  dealer,

  /// [ZMQ_ROUTER] = 6
  /// Asynchronous version of [ZMQ_REP]
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
  stream,

  /// [ZMQ_SERVER] = 12
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  server,

  /// [ZMQ_CLIENT] = 13
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  client,

  /// [ZMQ_RADIO] = 14
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  radio,

  /// [ZMQ_DISH] = 15
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  dish,

  /// [ZMQ_CHANNEL] = 16
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  channel,

  /// [ZMQ_PEER] = 17
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  peer,

  /// [ZMQ_RAW] = 18
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  raw,

  /// [ZMQ_SCATTER] = 19
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  scatter,

  /// [ZMQ_GATHER] = 20
  /// Note: This pattern is still in draft state and thus might not be supported by the zeromq library you’re using!
  gather,
}

/// Base socket
class ZBaseSocket {
  /// Native socket
  final ZMQSocket _socket;

  /// Global context
  final ZContext _context;

  /// Has this socket been closed?
  bool _closed = false;

  /// Construct a new [ZBaseSocket] with a given underlying ZMQSocket [_socket] and the global ZContext [_context]
  ZBaseSocket(this._socket, this._context);

  /// Sends the given [data] payload over this socket.
  ///
  /// The [flags] argument is a combination of the flags defined below:
  ///
  /// [ZMQ_SNDMORE] signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  ///
  /// [ZMQ_DONTWAIT] specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void send(final List<int> data, {final int flags = 0}) {
    _checkNotClosed();
    final ptr = malloc.allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    final result = _bindings.zmq_send(_socket, ptr.cast(), data.length, flags);
    malloc.free(ptr);
    _checkReturnCode(result, ignore: [EINTR]);
  }

  /// Sends the given [string] over this socket
  ///
  /// The [flags] argument is a combination of the flags defined below:
  ///
  /// [ZMQ_SNDMORE] signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  ///
  /// [ZMQ_DONTWAIT] specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendString(final String string, {final int flags = 0}) {
    send(
      string.codeUnits,
      flags: flags,
    );
  }

  /// Sends the given [frame] over this socket
  ///
  /// This is a convenience function and is the same as calling
  /// [send(frame.payload, flags: frame.hasMore ? ZMQ_SNDMORE : 0)]
  ///
  /// The [flags] argument is a combination of the flags defined below:
  ///
  /// [ZMQ_SNDMORE] signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  ///
  /// [ZMQ_DONTWAIT] specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendFrame(final ZFrame frame, {final int flags = 0}) {
    send(
      frame.payload,
      flags: flags | (frame.hasMore ? ZMQ_SNDMORE : 0),
    );
  }

  /// Sends the given multi-part [message] over this socket
  ///
  /// This is a convenience function.
  /// Note that the individual [ZFrame.hasMore] are ignored
  ///
  /// The [flags] argument is a combination of the flags defined below:
  ///
  /// [ZMQ_SNDMORE] signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  ///
  /// [ZMQ_DONTWAIT] specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendMessage(final ZMessage message, {final int flags = 0}) {
    final lastIndex = message.length - 1;
    for (int i = 0; i < message.length; ++i) {
      send(
        message.elementAt(i).payload,
        flags: flags | (i < lastIndex ? ZMQ_SNDMORE : 0),
      );
    }
  }

  /// Creates an endpoint for accepting connections and binds to it.
  ///
  /// The [address] argument is a string consisting of two parts as follows: 'transport://address'.
  /// The transport part specifies the underlying transport protocol to use.
  /// The meaning of the address part is specific to the underlying transport protocol selected.
  ///
  /// Throws [ZeroMQException] on error
  void bind(final String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _bindings.zmq_bind(_socket, endpointPointer);
    malloc.free(endpointPointer);
    _checkReturnCode(result, ignore: [EINTR]);
  }

  /// Connects the socket to an endpoint and then accepts incoming connections on that endpoint.
  ///
  /// The [address] argument is a string consisting of two parts as follows: 'transport://address'.
  /// The transport part specifies the underlying transport protocol to use.
  /// The meaning of the address part is specific to the underlying transport protocol selected.
  ///
  /// Throws [ZeroMQException] on error
  void connect(final String address) {
    _checkNotClosed();
    final endpointPointer = address.toNativeUtf8();
    final result = _bindings.zmq_connect(_socket, endpointPointer);
    malloc.free(endpointPointer);
    _checkReturnCode(result, ignore: [EINTR]);
  }

  /// Closes the socket and releases underlying resources.
  /// Note after closing a socket it can't be reopened/reconncted again
  void close() {
    if (!_closed) {
      _context._handleSocketClosed(this);
      _bindings.zmq_close(_socket);
      _closed = true;
    }
  }

  /// Set a socket [option] to a specific [value]
  ///
  /// Throws [ZeroMQException] on error
  void setOption(final int option, final String value) {
    final ptr = value.toNativeUtf8();
    final result = _bindings.zmq_setsockopt(
        _socket, option, ptr.cast<Uint8>(), ptr.length);
    malloc.free(ptr);
    _checkReturnCode(result, ignore: [EINTR]);
  }

  /// Sets the socket's long term secret key.
  /// You must set this on both CURVE client and server sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  ///
  /// Throws [ZeroMQException] on error
  void setCurveSecretKey(final String key) {
    setOption(ZMQ_CURVE_SECRETKEY, key);
  }

  /// Sets the socket's long term public key.
  /// You must set this on CURVE client sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  /// The public key must always be used with the matching secret key.
  ///
  /// Throws [ZeroMQException] on error
  void setCurvePublicKey(final String key) {
    setOption(ZMQ_CURVE_PUBLICKEY, key);
  }

  /// Sets the socket's long term server key.
  /// You must set this on CURVE client sockets, see zmq_curve(7).
  /// You can provide the [key] as a 40-character string encoded in the Z85 encoding format.
  /// This key must have been generated together with the server's secret key.
  ///
  /// Throws [ZeroMQException] on error
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
  ///
  /// Throws [ZeroMQException] on error
  void subscribe(final String topic) {
    setOption(ZMQ_SUBSCRIBE, topic);
  }

  /// The [ZMQ_UNSUBSCRIBE] option shall remove an existing message filter on a [ZMQ_SUB]
  /// socket. The filter specified must match an existing filter previously established with
  /// the [ZMQ_SUBSCRIBE] option. If the socket has several instances of the same filter
  /// attached the [ZMQ_UNSUBSCRIBE] option shall remove only one instance, leaving the rest in
  /// place and functional.
  ///
  /// Throws [ZeroMQException] on error
  void unsubscribe(final String topic) {
    setOption(ZMQ_UNSUBSCRIBE, topic);
  }

  /// Throws a [StateError] when called and this socket is closed
  void _checkNotClosed() {
    if (_closed) {
      throw StateError("This operation can't be performed on a closed socket!");
    }
  }
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
class ZSocket extends ZBaseSocket {
  /// StreamController for providing received [ZMessage]s as a stream
  late final StreamController<ZMessage> _controller;

  /// Stream of received [ZMessage]s
  Stream<ZMessage> get messages => _controller.stream;

  /// Stream of received [ZFrame]s (expanded [messages] stream)
  Stream<ZFrame> get frames => messages.expand((element) => element._frames);

  /// Stream of received payloads (expanded [frames] strem)
  Stream<Uint8List> get payloads => frames.map((e) => e.payload);

  /// Construct a new [ZSocket] with a given underlying ZMQSocket [_socket] and the global ZContext [_context]
  ZSocket(super._socket, super._context) {
    _controller = StreamController(onListen: () {
      _context._listen(this);
    }, onCancel: () {
      _context._stopListening(this);
    });
  }

  @override
  void close() {
    if (!_closed) {
      _controller.close();
    }
    super.close();
  }
}

/// A socket that is monitored by [ZMonitor] to receive events like
/// [ZEvent.CONNECTED], [ZEvent.DISCONNECTED] as well as other [ZEvent]s
class MonitoredZSocket extends ZSocket {
  /// Monitor monitoring this socket
  late final ZMonitor _monitor;

  /// Stream of received [ZEvent]s
  Stream<SocketEvent> get events => _monitor.events;

  /// Construct a new [MonitoredZSocket] with a given underlying ZMQSocket [_socket], the global ZContext [_context] and the given [event]s to monitor
  MonitoredZSocket(super.socket, super.context, int event) {
    _monitor = ZMonitor(context: _context, socket: this, event: event);
  }

  @override
  void close() {
    _monitor.close();
    super.close();
  }
}

/// A socket that only has blocking synchronized functions for receiving
class ZSyncSocket extends ZBaseSocket {
  /// Construct a new [ZSyncSocket] with a given underlying ZMQSocket [_socket] and the global ZContext [_context]
  ZSyncSocket(super._socket, super._context);

  /// Receive a message from the socket, blocking.
  /// [flags] can be ZMQ_DONTWAIT or ZMQ_SNDMORE.
  ///
  /// Useful for REQ/REP sockets where you want to wait for a reply.
  ///
  /// Returns the received message
  /// Throws a [StateError] when called and this socket is closed
  /// Throws [ZeroMQException] on error
  ZMessage recv({int flags = 0}) {
    _checkNotClosed();

    final frame = ZMQBindings.allocateMessage();
    var rc = _bindings.zmq_msg_init(frame); // rc == 0
    _checkReturnCode(rc);

    try {
      ZMessage zMessage = ZMessage();
      while (true) {
        rc = _bindings.zmq_msg_recv(frame, _socket, flags);
        _checkReturnCode(rc);
        final data = _bindings.zmq_msg_data(frame).cast<Uint8>();
        final copyOfData = Uint8List.fromList(data.asTypedList(rc));

        final hasMore = _bindings.zmq_msg_more(frame) != 0;

        zMessage.add(ZFrame(copyOfData, hasMore: hasMore));
        if (!hasMore) {
          return zMessage;
        }
      }
    } finally {
      rc = _bindings.zmq_msg_close(frame); // rc == 0
      malloc.free(frame);
      _checkReturnCode(rc);
    }
  }
}

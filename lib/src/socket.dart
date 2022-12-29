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
  ///
  /// The [nowait] parameter (defaults to false) specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void send(final List<int> data,
      {final bool more = false, final bool nowait = false}) {
    _checkNotClosed();
    final ptr = malloc.allocate<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);

    final sendParams = more ? ZMQ_SNDMORE : 0 | (nowait ? ZMQ_DONTWAIT : 0);
    final result =
        _bindings.zmq_send(_socket, ptr.cast(), data.length, sendParams);
    malloc.free(ptr);
    _checkReturnCode(result, ignore: [EINTR]);
  }

  /// Sends the given [string] over this socket
  ///
  /// The [more] parameter (defaults to false) signals that this is a multi-part
  /// message. ØMQ ensures atomic delivery of messages: peers shall receive
  /// either all message parts of a message or none at all.
  ///
  /// The [nowait] parameter (defaults to false) specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendString(final String string,
      {final bool more = false, final bool nowait = false}) {
    send(
      string.codeUnits,
      more: more,
      nowait: nowait,
    );
  }

  /// Sends the given [frame] over this socket
  ///
  /// This is a convenience function and is the same as calling
  /// [send(frame.payload, more: frame.hasMore)]
  ///
  /// The [nowait] parameter (defaults to false) specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendFrame(final ZFrame frame, {final bool nowait = false}) {
    send(
      frame.payload,
      more: frame.hasMore,
      nowait: nowait,
    );
  }

  /// Sends the given multi-part [message] over this socket
  ///
  /// This is a convenience function.
  /// Note that the individual [ZFrame.hasMore] are ignored
  ///
  /// The [nowait] parameter (defaults to false) specifies that the operation
  /// should be performed in non-blocking mode. For socket types (DEALER, PUSH)
  /// that block when there are no available peers (or all peers have full
  /// high-water mark). If the message cannot be queued on the socket,
  /// the zmq_send() function shall fail with errno set to EAGAIN.
  ///
  /// Throws [ZeroMQException] on error
  void sendMessage(final ZMessage message, {final bool nowait = false}) {
    final lastIndex = message.length - 1;
    for (int i = 0; i < message.length; ++i) {
      send(
        message.elementAt(i).payload,
        more: i < lastIndex ? true : false,
        nowait: nowait,
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
      _controller.close();
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

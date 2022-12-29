library dartzmq;

import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

part 'constants.dart';
part 'container.dart';
part 'exception.dart';
part 'monitor.dart';
part 'socket.dart';

// Native bindings
final ZMQBindings _bindings = ZMQBindings();

/// High-level wrapper around the ØMQ C++ api.
class ZContext {
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
    _context = _bindings.zmq_ctx_new();
    _poller = _bindings.zmq_poller_new();
    _startPolling();
  }

  /// Shutdown zeromq. Will stop [_poll] asynchronously.
  /// The returned [Future] will complete once [_poll] has been stopped
  Future stop() {
    _stopCompleter = Completer();
    _shutdown = true;
    return _stopCompleter!.future;
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
      final frame = ZMQBindings.allocateMessage();
      var rc = _bindings.zmq_msg_init(frame); // rc == 0
      _checkReturnCode(rc);

      for (var eventIdx = 0; eventIdx < availableEventCount; ++eventIdx) {
        final pollerEvent = pollerEvents[eventIdx];
        final socket = _createdSockets[pollerEvent.socket]!;

        // Receive multiple message parts
        ZMessage zMessage = ZMessage();
        while ((rc =
                _bindings.zmq_msg_recv(frame, socket._socket, ZMQ_DONTWAIT)) >=
            0) {
          // final size = _bindings.zmq_msg_size(msg);
          final data = _bindings.zmq_msg_data(frame).cast<Uint8>();
          final copyOfData = Uint8List.fromList(data.asTypedList(rc));

          final hasMore = _bindings.zmq_msg_more(frame) != 0;

          zMessage.add(ZFrame(copyOfData, hasMore: hasMore));

          if (!hasMore) {
            socket._controller.add(zMessage);
            zMessage = ZMessage();
          }
        }

        _checkReturnCode(rc, ignore: [EAGAIN, EINTR]);
      }

      rc = _bindings.zmq_msg_close(frame); // rc == 0
      malloc.free(frame);
      _checkReturnCode(rc);
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
  ZSocket createSocket(final SocketType mode) {
    final socket = _bindings.zmq_socket(_context, mode.index);
    final apiSocket = ZSocket(socket, this);
    _createdSockets[socket] = apiSocket;
    return apiSocket;
  }

  /// Create a new monitored socket of the given [mode] and optional [event]s
  /// to monitor
  MonitoredZSocket createMonitoredSocket(final SocketType mode,
      {final int event = ZMQ_EVENT_ALL}) {
    final socket = _bindings.zmq_socket(_context, mode.index);
    final apiSocket = MonitoredZSocket(socket, this, event);
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
}

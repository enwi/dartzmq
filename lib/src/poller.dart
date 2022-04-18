import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'bindings.dart';

part of 'zeromq.dart';

/// Internal commands for communication with the polling Isolate
enum _PollingMessage {
  /// Request that the Isolate stop polling
  stop,

  /// SendPort from the Isolate so the main thread can communicate
  send_port,

  /// Update the Isolate's socketCount when sockets are added or removed
  socket_count,

  /// Result from the polling Isolate with the polling events
  polling_result,

  /// Indicate that the polling Isolate has ended
  polling_stopped
}

/// Events types that the ZeroMQ poller will subscribe to
enum PollingEvent {

  /// Will subscribe to no events - can be updated later with modify()
  poll_none,

  /// Subscribe to incoming messages - triggered when at least one message can be received
  poll_in,

  /// Subscribe to outgoing messages - triggered when at least one message can be send
  poll_out,

  // Subscribe to both income and outgoing messages
  poll_in_out

  // Note: ZMQ_POLLERR and ZMQ_POLLPRI are not used here as they have no effect on the poller
  // and are generally not relevant to ZeroMQ sockets
}

/// Timeout in milliseconds for the ZeroMQ poller - the poller will wait up to this timeout
/// before returning. The poller returns as soon as data is available (i.e. potentially before
/// this timeout)
const int _pollingTimeoutMilliseconds = 100;

/// Convert the PollingEvent enum to the appropriate ZeroMQ flag so it can be sent to the poller
int _pollingEventToInt(PollingEvent type) {
  switch (type) {
    case PollingEvent.poll_none:
      return 0;
    case PollingEvent.poll_in:
      return ZMQ_POLLIN;
    case PollingEvent.poll_out:
      return ZMQ_POLLOUT;
    case PollingEvent.poll_in_out:
      return ZMQ_POLLIN | ZMQ_POLLOUT;
  }
}

/// Entry point for the polling Isolate. This will run until commanded to stop by the main thread
/// Three arguments are sent as a List<Object>: a SendPort, the current socket count, and the
/// address of the ZeroMQ poller object. The SendPort is used along with the local ReceivePort
/// to communicate with the main thread. The very first message to the SendPort must be the corresponding
/// ReceivePort to the local SendPort so the main thread can communicate with this Isolate
/// 
/// The socket count can be updated as the poller is running. When add() or remove() is called, a 
/// message will be sent to this Isolate and the count will be updated.
/// 
/// Since pointers can not be sent directly to Isolates, the address is passed and the pointer
/// to the ZeroMQ poller is reconstructed.
/// 
/// Likewise, when messages are received through the poller, the addresses of the appropriate
/// sockets are sent to the main thread and reconstructed there
void _poll(List<Object> arguments) async {

  // Reconstruct the  
  SendPort sender = arguments[0] as SendPort;
  int socketCount = arguments[1] as int;
  ZMQPoller poller = ZMQPoller.fromAddress(arguments[2] as int);

  // Flag to run the poller loop - will only be set to false by a message from the main thread
  bool run = true;

  // Create a ReceivedPort to message the outside world
  ReceivePort receiver = ReceivePort();

  // Listen handler for the receive port
  receiver.listen((msg) {
    var message = msg as List<Object>;

    switch (message[0] as _PollingMessage) {

      // Update the socket count - this determines how many ZMQPollerEvents are alloc'd
      case _PollingMessage.socket_count:
        socketCount = message[1] as int;
      break;

      // Stop the polling thread and exit this Isolate
      case _PollingMessage.stop:
        run = false;
      break;
      default:break;
    }

  });

  // Immediately send the corrsponding SendPort so the main thread can start communicating
  sender.send([_PollingMessage.send_port, receiver.sendPort]);

  while(run) {
    // Allocate the appropriate number of ZMQPollerEvents based on how many sockets have been added to the poller
    // This is done every loop to account for the possibility of socketCount changing
    final pollerEvents = malloc.allocate<ZMQPollerEvent>(sizeOf<ZMQPollerEvent>() * socketCount);

    // Poll. This will block up to the _pollingTimeoutMilliseconds, but may return sooner if data is available
    final availableEventCount = _bindings.zmq_poller_wait_all(poller, pollerEvents, socketCount, _pollingTimeoutMilliseconds);

    // Produce a list with the addresses of the sockets that have data available
    List<int> list = [];
    for (int i = 0; i < availableEventCount; i++) {
      list.add(pollerEvents[i].socket.address);
    }

    // Send the socket addresses. If there are not sockets with data, just send the return value of the poll function
    if (availableEventCount > 0) {        
      sender.send([_PollingMessage.polling_result, availableEventCount, list]);
    }
    else {
      sender.send([_PollingMessage.polling_result, availableEventCount]);
    }

    // Free the memory allocated for the ZMQPollerEvents
    malloc.free(pollerEvents);

    // Give up the time slice to let the main thread run
    await Future.delayed(Duration.zero);
  }

  // Let the main thread know we have finished and close our ReceivePort
  sender.send([_PollingMessage.polling_stopped]);
  receiver.close();
}

/// Wrapper of the zmq_poller class
class ZPoller {
  // The ZeroMQ poller 
  final ZMQPoller _poller = _bindings.zmq_poller_new();

  // Map our sockets to the underlying ZeroMQ sockets
  final Map<ZMQSocket, ZSocket> _sockets = {};

  // Used to communicate with the poller Isolate
  final ReceivePort _receiver = ReceivePort();

  // Used to communicate with the poller Isolate
  SendPort? _sender;

  // Used to wait until the poller Isolate has stopped
  Completer? _shutdownCompleter;

  ZPoller() {
    // Attach our listener to receive messages from the poller Isolate
    _receiver.listen(_pollListener);
  }

  /// Adds [socket] to the ZeroMQ poller. Use [events] to subscribe to socket events. 
  /// Events can be added or updated later by calling modify()
  void add(ZSocket socket, PollingEvent events) {
    _bindings.zmq_poller_add(_poller, socket._socket, nullptr, _pollingEventToInt(events));
    _sockets[socket._socket] = socket;
    _sender?.send(_sockets.length);
  }

  /// Removes [socket] from the ZeroMQ poller. There is no effect if the socket is not
  /// currently registered
  void remove(ZSocket socket) {
    if (_sockets.containsKey(socket._socket)) {
      _bindings.zmq_poller_remove(_poller, socket._socket);
      _sockets.remove(socket._socket);
      _sender?.send(_sockets.length);
    }
  }

  /// Modify the events associated with [socket] to [events]. There is no effect if the
  /// socket is not registered.
  void modify(ZSocket socket, PollingEvent events) {
    if (_sockets.containsKey(socket._socket)) {
      _bindings.zmq_poller_modify(_poller, socket._socket, _pollingEventToInt(events));
    }
  }

  /// Start polling. Polling will happen asynchronously in an Isolate
  void start() {
    Isolate.spawn(_poll, [_receiver.sendPort, _sockets.length, _poller.address]); 
  }

  /// Stop polling. Polling can be restarted with start()
  void stop() {
    _sender?.send([_PollingMessage.stop]);
    _sender = null;
  }

  /// Shutdown the poller. This will unregister all sockets and free the ZeroMQ poller.
  /// Polling should NOT be started again on this poller after calling shutdown().
  /// This call should be awaited to ensure the poller Isolate has completely stopped.
  Future<void> shutdown() async {
    _sender?.send([_PollingMessage.stop]);
    _shutdownCompleter = Completer();

    // if send port is null that means the _poll isolate as never spawned, so skip this
    if (_sender != null) {
      await _shutdownCompleter?.future;
    }

    _receiver.close();
    _sockets.clear();
    Pointer<ZMQPoller> pollerPointer = malloc.allocate<ZMQPoller>(0);
    pollerPointer.value = _poller;
    _bindings.zmq_poller_destroy(pollerPointer);
    malloc.free(pollerPointer);
    return;
  }

  /// Listener for the poller Isolate
  void _pollListener(dynamic message) async {
    // The Isolate will send a List<Object> the first item of which should be a command
    List<Object> response = message as List<Object>;  
    var pollingMessage = response[0] as _PollingMessage;

    switch (response[0] as _PollingMessage) {
      // Update the SendPort to communicate with the Isolate
      case _PollingMessage.send_port:
        _sender = response[1] as SendPort;
      break;

      // The polling Isolate has finished and shutdown can be completed
      case _PollingMessage.polling_stopped:
        _shutdownCompleter?.complete();
      break;

      // Results of the polling operation
      case _PollingMessage.polling_result:
        // The number of sockets that have data available
        int count = response[1] as int;
        if (count > 0) {
          // The poller sends a list of socket addresses
          var polledSocketAddresses = response[2] as List<int>;        

          // Allocate some room for the messages we are about to receive
          final msg = _allocateMessage();
          var returnCode = _bindings.zmq_msg_init(msg); // rc == 0
          _checkReturnCode(returnCode);

          for (var eventIdx = 0; eventIdx < count; ++eventIdx) {
            // Get the zmq_socket from the address and see if it matches one of the
            // registered ZSockets
            ZMQSocket zmqsocket = ZMQSocket.fromAddress(polledSocketAddresses[eventIdx]);
            ZSocket? socket = _sockets[zmqsocket];

            if (socket == null) {
              continue;
            }

            // Receive multiple message parts
            ZMessage zMessage = ZMessage();
            bool hasMore = true;
            while ((returnCode = _bindings.zmq_msg_recv(msg, socket._socket, ZMQ_DONTWAIT)) > 0) {
              final data = _bindings.zmq_msg_data(msg).cast<Uint8>();

              final copyOfData = Uint8List.fromList(data.asTypedList(returnCode));
              hasMore = _bindings.zmq_msg_more(msg) != 0;

              zMessage.add(ZFrame(copyOfData, hasMore: hasMore));

              // If that is all the data, give it to the socket's StreamController
              if (!hasMore) {
                socket._controller.add(zMessage);
                zMessage = ZMessage();
              }
            }

            _checkReturnCode(returnCode, ignore: [EAGAIN]);
          }

          // Free the message that was allocated
          returnCode = _bindings.zmq_msg_close(msg);
          _checkReturnCode(returnCode);
          malloc.free(msg);
        }
      break;

      default:break;
    }
  }
}

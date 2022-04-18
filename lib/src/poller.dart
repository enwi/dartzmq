import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'bindings.dart';

part of 'zeromq.dart';

enum _PollingMessage {
  stop,
  send_port,
  socket_count,
  polling_result,
  polling_stopped
}

const int _pollingTimeoutMilliseconds = 100;

void _poll(List<Object> arguments) async {
    SendPort sender = arguments[0] as SendPort;
    int socketCount = arguments[1] as int;
    ZMQPoller poller = ZMQPoller.fromAddress(arguments[2] as int);

    bool run = true;
    ReceivePort receiver = ReceivePort();
    sender.send([_PollingMessage.send_port, receiver.sendPort]);

    receiver.listen((msg) {
      var message = msg as List<Object>;

      switch (message[0] as _PollingMessage) {
        case _PollingMessage.socket_count:
          socketCount = message[1] as int;
        break;
        case _PollingMessage.stop:
          run = false;
        break;
        default:break;
      }

    });

    while(run) {
      final pollerEvents = malloc.allocate<ZMQPollerEvent>(sizeOf<ZMQPollerEvent>() * socketCount);
      final availableEventCount = _bindings.zmq_poller_wait_all(poller, pollerEvents, socketCount, _pollingTimeoutMilliseconds);

      List<int> list = [];
      for (int i = 0; i < availableEventCount; i++) {
        list.add(pollerEvents[i].socket.address);
      }

      if (availableEventCount > 0) {        
        sender.send([_PollingMessage.polling_result, availableEventCount, list]);
      }
      else {
        sender.send([_PollingMessage.polling_result, 0]);
      }
      malloc.free(pollerEvents);
      await Future.delayed(Duration.zero);

    }

    sender.send([_PollingMessage.polling_stopped]);

    receiver.close();
}

enum PollingEvent {
  poll_none,
  poll_in,
  poll_out,
  poll_in_out,
  poll_err,
  poll_pri
}

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
    case PollingEvent.poll_err:
      return ZMQ_POLLERR;
    case PollingEvent.poll_pri:
      return ZMQ_POLLPRI;
  }
}

class ZPoller {
  final ZMQPoller _poller = _bindings.zmq_poller_new();
  final Map<ZMQSocket, ZSocket> _sockets = {};
  final ReceivePort _receiver = ReceivePort();
  SendPort? _sender;
  Completer? _completer;

  ZPoller() {
    _receiver.listen(_pollListener);
  }

  void add(ZSocket socket, PollingEvent events) {
    _bindings.zmq_poller_add(_poller, socket._socket, nullptr, _pollingEventToInt(events));
    _sockets[socket._socket] = socket;
    _sender?.send(_sockets.length);
  }

  void remove(ZSocket socket) {
    _bindings.zmq_poller_remove(_poller, socket._socket);
    _sockets.remove(socket._socket);
    _sender?.send(_sockets.length);
  }

  void modify(ZSocket socket, PollingEvent events) {
    _bindings.zmq_poller_modify(_poller, socket._socket, _pollingEventToInt(events));
  }

  void start() {
    Isolate.spawn(_poll, [_receiver.sendPort, _sockets.length, _poller.address]); 
  }

  void stop() {
    _sender?.send([_PollingMessage.stop]);
    _sender = null;
  }

  Future<void> shutdown() async {
    _sender?.send([_PollingMessage.stop]);
    _completer = Completer();

    // if send port is null that means the _poll isolate as never spawned, so skip this
    if (_sender != null) {
      await _completer?.future;
    }

    _receiver.close();
    _sockets.clear();
    Pointer<ZMQPoller> pollerPointer = malloc.allocate<ZMQPoller>(0);
    pollerPointer.value = _poller;
    _bindings.zmq_poller_destroy(pollerPointer);
    malloc.free(pollerPointer);
    return;
  }

  void _pollListener(dynamic message) async {
    List<Object> response = message as List<Object>;
  
    var pollingMessage = response[0] as _PollingMessage;

    switch (response[0] as _PollingMessage) {
      case _PollingMessage.send_port:
        _sender = response[1] as SendPort;
      break;

      case _PollingMessage.polling_stopped:
        _completer?.complete();
      break;

      case _PollingMessage.polling_result:
        int count = response[1] as int;

        if (count > 0) {

          var pollerEvents = response[2] as List<int>;        

          final msg = _allocateMessage();
          var rc = _bindings.zmq_msg_init(msg); // rc == 0
          _checkReturnCode(rc);

          for (var eventIdx = 0; eventIdx < count; ++eventIdx) {
            final pollerEvent = pollerEvents[eventIdx];
            ZMQSocket zmqsocket = ZMQSocket.fromAddress(pollerEvents[eventIdx]);
            ZSocket? socket = _sockets[zmqsocket];

            if (socket == null) {
              continue;
            }

            // Receive multiple message parts
            ZMessage zMessage = ZMessage();
            bool hasMore = true;
            while ((rc = _bindings.zmq_msg_recv(msg, socket._socket, ZMQ_DONTWAIT)) > 0) {
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

          rc = _bindings.zmq_msg_close(msg);
          _checkReturnCode(rc);

          malloc.free(msg);
        }
      break;

      default:break;
    }
  }
}

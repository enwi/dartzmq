// ignore_for_file: non_constant_identifier_names
import 'dart:ffi';

import 'package:ffi/ffi.dart';

part 'constants.dart';

typedef ZMQContext = Pointer<Void>;
typedef ZMQSocket = Pointer<Void>;
typedef ZMQPoller = Pointer<Void>;
typedef ZMQMessage = Pointer<Void>;

typedef zmq_bind_native = Int32 Function(
    ZMQSocket socket, Pointer<Utf8> endpoint);
typedef zmq_bind_dart = int Function(ZMQSocket socket, Pointer<Utf8> endpoint);

typedef zmq_connect_native = Int32 Function(
    ZMQSocket socket, Pointer<Utf8> endpoint);
typedef zmq_connect_dart = int Function(
    ZMQSocket socket, Pointer<Utf8> endpoint);

typedef zmq_errno_native = Int32 Function();
typedef zmq_errno_dart = int Function();

typedef zmq_ctx_term_native = Int32 Function(ZMQContext context);
typedef zmq_ctx_term_dart = int Function(ZMQContext context);

typedef zmq_ctx_new_native = ZMQContext Function();
typedef zmq_ctx_new_dart = ZMQContext Function();

// IO multiplexing
typedef zmq_poller_new_native = ZMQPoller Function();
typedef zmq_poller_new_dart = ZMQPoller Function();

typedef zmq_poller_destroy_native = Int32 Function(ZMQPoller poller);
typedef zmq_poller_destroy_dart = int Function(ZMQPoller poller);

typedef zmq_poller_add_native = Int32 Function(
    ZMQPoller poller, ZMQSocket socket, Pointer<Void> userData, Int16 events);
typedef zmq_poller_add_dart = int Function(
    ZMQPoller poller, ZMQSocket socket, Pointer<Void> userData, int events);

typedef zmq_poller_remove_native = Int32 Function(
    ZMQPoller poller, ZMQSocket sockeft);
typedef zmq_poller_remove_dart = int Function(
    ZMQPoller poller, ZMQSocket socket);

typedef zmq_poll_native = Int32 Function(
    Pointer<ZMQPollItem> items, Int32 nitems, Int64 timeout);
typedef zmq_poll_dart = int Function(
    Pointer<ZMQPollItem> items, int nitems, int timeout);

typedef zmq_poller_wait_all_native = Int32 Function(ZMQPoller poller,
    Pointer<ZMQPollerEvent> events, Int32 count, Int64 timeout);
typedef zmq_poller_wait_all_dart = int Function(
    ZMQPoller poller, Pointer<ZMQPollerEvent> events, int count, int timeout);

// Messages
typedef zmq_msg_init_native = Int32 Function(ZMQMessage message);
typedef zmq_msg_init_dart = int Function(ZMQMessage message);

typedef zmq_msg_size_native = IntPtr Function(ZMQMessage message);
typedef zmq_msg_size_dart = int Function(ZMQMessage message);

typedef zmq_msg_data_native = Pointer<Void> Function(ZMQMessage message);
typedef zmq_msg_data_dart = Pointer<Void> Function(ZMQMessage message);

typedef zmq_msg_recv_native = Int32 Function(
    ZMQMessage msg, ZMQSocket socket, Int32 flags);
typedef zmq_msg_recv_dart = int Function(
    ZMQMessage msg, ZMQSocket socket, int flags);

typedef zmq_msg_more_native = Int32 Function(ZMQMessage message);
typedef zmq_msg_more_dart = int Function(ZMQMessage message);

typedef zmq_msg_close_native = Int32 Function(ZMQMessage msg);
typedef zmq_msg_close_dart = int Function(ZMQMessage msg);

typedef zmq_socket_native = ZMQSocket Function(ZMQContext context, Int32 type);
typedef zmq_socket_dart = ZMQSocket Function(ZMQContext context, int type);

typedef zmq_close_native = Int32 Function(ZMQSocket socket);
typedef zmq_close_dart = int Function(ZMQSocket socket);

typedef zmq_send_native = Int32 Function(
    ZMQSocket socket, Pointer<Void> buffer, IntPtr size, Int32 flags);
typedef zmq_send_dart = int Function(
    ZMQSocket socket, Pointer<Void> buffer, int size, int flags);

typedef zmq_setsockopt_native = Void Function(
    ZMQSocket socket, Int32 option, Pointer<Uint8> optval, IntPtr optvallen);
typedef zmq_setsockopt_dart = void Function(
    ZMQSocket socket, int option, Pointer<Uint8> optval, int optvallen);

// Native types
// class ZMQContext extends Struct {}

// class ZMQSocket extends Struct {/* void* */}

// class ZMQPoller extends Struct {/* void* */}

// class ZMQMessage extends Struct {
//   // this struct actually has some values, but we're supposed to extract data
//   // via functions, so we treat this as a typed void*
// }

class ZMQPollerEvent extends Struct {
  external ZMQSocket socket;
  @Int32()
  external int fd;

  external Pointer<Void> userData;
  @Int16()
  external int events;
}

class ZMQPollItem extends Struct {
  external ZMQSocket socket;
  @Int32()
  external int fd;

  @Int16()
  external int events;
  @Int16()
  external int revents;
}

class ZMQBindings {
  final DynamicLibrary library;

  late final zmq_errno_dart zmq_errno;

  late final zmq_bind_dart zmq_bind;
  late final zmq_connect_dart zmq_connect;
  late final zmq_ctx_new_dart zmq_ctx_new;
  late final zmq_ctx_term_dart zmq_ctx_term;
  late final zmq_socket_dart zmq_socket;
  late final zmq_close_dart zmq_close;

  late final zmq_send_dart zmq_send;

  late final zmq_poller_new_dart zmq_poller_new;
  late final zmq_poller_destroy_dart zmq_poller_destroy;
  late final zmq_poller_add_dart zmq_poller_add;
  late final zmq_poller_remove_dart zmq_poller_remove;
  late final zmq_poll_dart zmq_poll;
  late final zmq_poller_wait_all_dart zmq_poller_wait_all;

  late final zmq_msg_init_dart zmq_msg_init;
  late final zmq_msg_close_dart zmq_msg_close;
  late final zmq_msg_size_dart zmq_msg_size;
  late final zmq_msg_data_dart zmq_msg_data;
  late final zmq_msg_recv_dart zmq_msg_recv;
  late final zmq_msg_more_dart zmq_msg_more;

  late final zmq_setsockopt_dart zmq_setsockopt;

  ZMQBindings(this.library) {
    zmq_errno =
        library.lookupFunction<zmq_errno_native, zmq_errno_dart>('zmq_errno');
    zmq_bind =
        library.lookupFunction<zmq_bind_native, zmq_bind_dart>('zmq_bind');
    zmq_connect = library
        .lookupFunction<zmq_connect_native, zmq_connect_dart>('zmq_connect');
    zmq_ctx_new = library
        .lookupFunction<zmq_ctx_new_native, zmq_ctx_new_dart>('zmq_ctx_new');
    zmq_ctx_term = library
        .lookupFunction<zmq_ctx_term_native, zmq_ctx_term_dart>('zmq_ctx_term');
    zmq_socket = library
        .lookupFunction<zmq_socket_native, zmq_socket_dart>('zmq_socket');
    zmq_close =
        library.lookupFunction<zmq_close_native, zmq_close_dart>('zmq_close');

    zmq_send =
        library.lookupFunction<zmq_send_native, zmq_send_dart>('zmq_send');

    zmq_poller_new =
        library.lookupFunction<zmq_poller_new_native, zmq_poller_new_dart>(
            'zmq_poller_new');
    zmq_poller_destroy = library.lookupFunction<zmq_poller_destroy_native,
        zmq_poller_destroy_dart>('zmq_poller_destroy');
    zmq_poller_add =
        library.lookupFunction<zmq_poller_add_native, zmq_poller_add_dart>(
            'zmq_poller_add');
    zmq_poller_remove = library.lookupFunction<zmq_poller_remove_native,
        zmq_poller_remove_dart>('zmq_poller_remove');
    zmq_poll =
        library.lookupFunction<zmq_poll_native, zmq_poll_dart>('zmq_poll');
    zmq_poller_wait_all = library.lookupFunction<zmq_poller_wait_all_native,
        zmq_poller_wait_all_dart>('zmq_poller_wait_all');

    zmq_msg_init = library
        .lookupFunction<zmq_msg_init_native, zmq_msg_init_dart>('zmq_msg_init');
    zmq_msg_close =
        library.lookupFunction<zmq_msg_close_native, zmq_msg_close_dart>(
            'zmq_msg_close');
    zmq_msg_size = library
        .lookupFunction<zmq_msg_size_native, zmq_msg_size_dart>('zmq_msg_size');
    zmq_msg_data = library
        .lookupFunction<zmq_msg_data_native, zmq_msg_data_dart>('zmq_msg_data');
    zmq_msg_recv = library
        .lookupFunction<zmq_msg_recv_native, zmq_msg_recv_dart>('zmq_msg_recv');
    zmq_msg_more = library
        .lookupFunction<zmq_msg_more_native, zmq_msg_more_dart>('zmq_msg_more');

    zmq_setsockopt =
        library.lookupFunction<zmq_setsockopt_native, zmq_setsockopt_dart>(
            'zmq_setsockopt');
  }
}

// ignore_for_file: non_constant_identifier_names

import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef ZMQContext = Pointer<Void>;
typedef ZMQMessage = Pointer<Void>;
typedef ZMQPoller = Pointer<Void>;
typedef ZMQSocket = Pointer<Void>;

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

typedef ZmqHasNative = Int32 Function(Pointer<Utf8> capability);
typedef ZmqHasDart = int Function(Pointer<Utf8> capability);

typedef ZmqBindNative = Int32 Function(
    ZMQSocket socket, Pointer<Utf8> endpoint);
typedef ZmqBindDart = int Function(ZMQSocket socket, Pointer<Utf8> endpoint);

typedef ZmqConnectNative = Int32 Function(
    ZMQSocket socket, Pointer<Utf8> endpoint);
typedef ZmqConnectDart = int Function(ZMQSocket socket, Pointer<Utf8> endpoint);

typedef ZmqErrnoNative = Int32 Function();
typedef ZmqErrnoDart = int Function();

typedef ZmqCtxTermNative = Int32 Function(ZMQContext context);
typedef ZmqCtxTermDart = int Function(ZMQContext context);

typedef ZmqCtxNewNative = ZMQContext Function();
typedef ZmqCtxNewDart = ZMQContext Function();

// IO multiplexing
typedef ZmqPollerNewNative = ZMQPoller Function();
typedef ZmqPollerNewDart = ZMQPoller Function();

typedef ZmqPollerModifyNative = Int32 Function(
    ZMQPoller poller, ZMQSocket socket, Int16 events);
typedef ZmqPollerModifyDart = int Function(
    ZMQPoller poller, ZMQSocket socket, int events);

typedef ZmqPollerDestroyNative = Int32 Function(Pointer<ZMQPoller> poller);
typedef ZmqPollerDestroyDart = int Function(Pointer<ZMQPoller> poller);

typedef ZmqPollerAddNative = Int32 Function(
    ZMQPoller poller, ZMQSocket socket, Pointer<Void> userData, Int16 events);
typedef ZmqPollerAddDart = int Function(
    ZMQPoller poller, ZMQSocket socket, Pointer<Void> userData, int events);

typedef ZmqPollerRemoveNative = Int32 Function(
    ZMQPoller poller, ZMQSocket sockeft);
typedef ZmqPollerRemoveDart = int Function(ZMQPoller poller, ZMQSocket socket);

typedef ZmqPollNative = Int32 Function(
    Pointer<ZMQPollItem> items, Int32 nitems, Int64 timeout);
typedef ZmqPollDart = int Function(
    Pointer<ZMQPollItem> items, int nitems, int timeout);

typedef ZmqPollerWaitAllNative = Int32 Function(ZMQPoller poller,
    Pointer<ZMQPollerEvent> events, Int32 count, Int64 timeout);
typedef ZmqPollerWaitAllDart = int Function(
    ZMQPoller poller, Pointer<ZMQPollerEvent> events, int count, int timeout);

// Messages
typedef ZmqMsgInitNative = Int32 Function(ZMQMessage message);
typedef ZmqMsgInitDart = int Function(ZMQMessage message);

typedef ZmqMsgSizeNative = IntPtr Function(ZMQMessage message);
typedef ZmqMsgSizeDart = int Function(ZMQMessage message);

typedef ZmqMsgDataNative = Pointer<Void> Function(ZMQMessage message);
typedef ZmqMsgDataDart = Pointer<Void> Function(ZMQMessage message);

typedef ZmqMsgRecvNative = Int32 Function(
    ZMQMessage msg, ZMQSocket socket, Int32 flags);
typedef ZmqMsgRecvDart = int Function(
    ZMQMessage msg, ZMQSocket socket, int flags);

typedef ZmqMsgMoreNative = Int32 Function(ZMQMessage message);
typedef ZmqMsgMoreDart = int Function(ZMQMessage message);

typedef ZmqMsgCloseNative = Int32 Function(ZMQMessage msg);
typedef ZmqMsgCloseDart = int Function(ZMQMessage msg);

typedef ZmqSocketNative = ZMQSocket Function(ZMQContext context, Int32 type);
typedef ZmqSocketDart = ZMQSocket Function(ZMQContext context, int type);

typedef ZmqCloseNative = Int32 Function(ZMQSocket socket);
typedef ZmqCloseDart = int Function(ZMQSocket socket);

typedef ZmqSendNative = Int32 Function(
    ZMQSocket socket, Pointer<Void> buffer, IntPtr size, Int32 flags);
typedef ZmqSendDart = int Function(
    ZMQSocket socket, Pointer<Void> buffer, int size, int flags);

typedef ZmqSetsockoptNative = Int32 Function(
    ZMQSocket socket, Int32 option, Pointer<Uint8> optval, IntPtr optvallen);
typedef ZmqSetsockoptDart = int Function(
    ZMQSocket socket, int option, Pointer<Uint8> optval, int optvallen);

typedef ZmqSocketMonitorNative = Int32 Function(
    ZMQSocket socket, Pointer<Utf8> endpoint, Int16 events);
typedef ZmqSocketMonitorDart = int Function(
    ZMQSocket socket, Pointer<Utf8> endpoint, int events);

class ZMQBindings {
  late final DynamicLibrary library;

  late final ZmqHasDart zmq_has;

  late final ZmqErrnoDart zmq_errno;

  late final ZmqBindDart zmq_bind;
  late final ZmqConnectDart zmq_connect;
  late final ZmqCtxNewDart zmq_ctx_new;
  late final ZmqCtxTermDart zmq_ctx_term;
  late final ZmqSocketDart zmq_socket;
  late final ZmqCloseDart zmq_close;

  late final ZmqSendDart zmq_send;

  late final ZmqPollerNewDart zmq_poller_new;
  late final ZmqPollerModifyDart zmq_poller_modify;
  late final ZmqPollerDestroyDart zmq_poller_destroy;
  late final ZmqPollerAddDart zmq_poller_add;
  late final ZmqPollerRemoveDart zmq_poller_remove;
  late final ZmqPollDart zmq_poll;
  late final ZmqPollerWaitAllDart zmq_poller_wait_all;

  late final ZmqMsgInitDart zmq_msg_init;
  late final ZmqMsgCloseDart zmq_msg_close;
  late final ZmqMsgSizeDart zmq_msg_size;
  late final ZmqMsgDataDart zmq_msg_data;
  late final ZmqMsgRecvDart zmq_msg_recv;
  late final ZmqMsgMoreDart zmq_msg_more;

  late final ZmqSetsockoptDart zmq_setsockopt;

  late final ZmqSocketMonitorDart zmq_socket_monitor;

  ZMQBindings() {
    _initLibrary();
    _lookupFunctions();
  }

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
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.process();
    }

    final String fullPath = _platformPath(name, path: path);
    return DynamicLibrary.open(fullPath);
  }

  bool _loadLibrary(final String name) {
    try {
      library = _dlOpenPlatformSpecific(name);
      return true;
    } catch (err) {
      log('Failed to load library $name:  ${err.toString()}', name: 'dartzmq');
    }
    return false;
  }

  void _initLibrary() {
    final loaded = _loadLibrary('zmq') ||
        _loadLibrary('libzmq') ||
        _loadLibrary('libzmq-v142-mt-4_3_5');
    if (!loaded) {
      throw Exception('Could not load any zeromq library');
    }
  }

  void _lookupFunctions() {
    zmq_has = library.lookupFunction<ZmqHasNative, ZmqHasDart>('zmq_has');
    zmq_errno =
        library.lookupFunction<ZmqErrnoNative, ZmqErrnoDart>('zmq_errno');
    zmq_bind = library.lookupFunction<ZmqBindNative, ZmqBindDart>('zmq_bind');
    zmq_connect =
        library.lookupFunction<ZmqConnectNative, ZmqConnectDart>('zmq_connect');
    zmq_ctx_new =
        library.lookupFunction<ZmqCtxNewNative, ZmqCtxNewDart>('zmq_ctx_new');
    zmq_ctx_term = library
        .lookupFunction<ZmqCtxTermNative, ZmqCtxTermDart>('zmq_ctx_term');
    zmq_socket =
        library.lookupFunction<ZmqSocketNative, ZmqSocketDart>('zmq_socket');
    zmq_close =
        library.lookupFunction<ZmqCloseNative, ZmqCloseDart>('zmq_close');

    zmq_send = library.lookupFunction<ZmqSendNative, ZmqSendDart>('zmq_send');

    zmq_poller_new = library
        .lookupFunction<ZmqPollerNewNative, ZmqPollerNewDart>('zmq_poller_new');
    zmq_poller_modify =
        library.lookupFunction<ZmqPollerModifyNative, ZmqPollerModifyDart>(
            'zmq_poller_modify');
    zmq_poller_destroy =
        library.lookupFunction<ZmqPollerDestroyNative, ZmqPollerDestroyDart>(
            'zmq_poller_destroy');
    zmq_poller_add = library
        .lookupFunction<ZmqPollerAddNative, ZmqPollerAddDart>('zmq_poller_add');
    zmq_poller_remove =
        library.lookupFunction<ZmqPollerRemoveNative, ZmqPollerRemoveDart>(
            'zmq_poller_remove');
    zmq_poll = library.lookupFunction<ZmqPollNative, ZmqPollDart>('zmq_poll');
    zmq_poller_wait_all =
        library.lookupFunction<ZmqPollerWaitAllNative, ZmqPollerWaitAllDart>(
            'zmq_poller_wait_all');

    zmq_msg_init = library
        .lookupFunction<ZmqMsgInitNative, ZmqMsgInitDart>('zmq_msg_init');
    zmq_msg_close = library
        .lookupFunction<ZmqMsgCloseNative, ZmqMsgCloseDart>('zmq_msg_close');
    zmq_msg_size = library
        .lookupFunction<ZmqMsgSizeNative, ZmqMsgSizeDart>('zmq_msg_size');
    zmq_msg_data = library
        .lookupFunction<ZmqMsgDataNative, ZmqMsgDataDart>('zmq_msg_data');
    zmq_msg_recv = library
        .lookupFunction<ZmqMsgRecvNative, ZmqMsgRecvDart>('zmq_msg_recv');
    zmq_msg_more = library
        .lookupFunction<ZmqMsgMoreNative, ZmqMsgMoreDart>('zmq_msg_more');

    zmq_setsockopt =
        library.lookupFunction<ZmqSetsockoptNative, ZmqSetsockoptDart>(
            'zmq_setsockopt');

    zmq_socket_monitor =
        library.lookupFunction<ZmqSocketMonitorNative, ZmqSocketMonitorDart>(
            'zmq_socket_monitor');
  }

  /// Allocates memory and casts it to a [ZMQMessage]
  static ZMQMessage allocateMessage() {
    return malloc.allocate<Uint8>(64).cast();
  }
}
